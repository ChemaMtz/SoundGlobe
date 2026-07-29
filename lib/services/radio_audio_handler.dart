import 'dart:async';
import 'dart:convert';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../models/radio_station.dart';

/// Manejador de audio que integra just_audio, audio_service,
/// lectura de Metadata ICY en tiempo real (nombre de canción), búsqueda de carátula en iTunes API,
/// controles de Siguiente / Anterior y reconexión automática anti-cortes de señal.
class RadioAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  final _currentStationSubject = BehaviorSubject<RadioStation?>.seeded(null);
  Stream<RadioStation?> get currentStationStream => _currentStationSubject.stream;
  RadioStation? get currentStation => _currentStationSubject.value;

  // Metadata ICY de la canción en vivo (Artista - Canción)
  final _nowPlayingTrackSubject = BehaviorSubject<String?>.seeded(null);
  Stream<String?> get nowPlayingTrackStream => _nowPlayingTrackSubject.stream;
  String? get nowPlayingTrack => _nowPlayingTrackSubject.value;

  // Carátula HD obtenida dinámicamente (de iTunes o Favicon de la emisora)
  final _albumArtUrlSubject = BehaviorSubject<String?>.seeded(null);
  Stream<String?> get albumArtUrlStream => _albumArtUrlSubject.stream;
  String? get albumArtUrl => _albumArtUrlSubject.value;

  final _errorSubject = BehaviorSubject<String?>.seeded(null);
  Stream<String?> get errorStream => _errorSubject.stream;

  // Cola de reproducción (Playlist activa)
  List<RadioStation> _queueStations = [];
  int _currentIndex = -1;

  // Reintento automático anti-cortes de señal
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  bool _isManualStop = false;

  // Temporizador de apagado automático (Sleep Timer)
  Timer? _sleepTimer;
  Timer? _countdownTicker;
  final _sleepTimerRemainingSubject = BehaviorSubject<Duration?>.seeded(null);
  Stream<Duration?> get sleepTimerRemainingStream => _sleepTimerRemainingSubject.stream;
  Duration? get sleepTimerRemaining => _sleepTimerRemainingSubject.value;

  RadioAudioHandler() {
    _init();
  }

  void _init() {
    _player.playbackEventStream.listen(_broadcastState, onError: (Object e, StackTrace st) {
      debugPrint('Error en flujo de radio: $e');
      _handleStreamDrop();
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _handleStreamDrop();
      }
    });

    // Escuchar metadatos ICY de la transmisión de radio (nombre de la canción en vivo)
    _player.icyMetadataStream.listen((icy) {
      final title = icy?.info?.title;
      if (title != null && title.trim().isNotEmpty) {
        final cleanTitle = title.trim();
        debugPrint('Radio ICY Metadata: $cleanTitle');
        _nowPlayingTrackSubject.add(cleanTitle);
        _fetchITunesAlbumArt(cleanTitle);
      }
    });
  }

  /// Busca la carátula en alta resolución en la API pública de iTunes basada en la canción que suena
  Future<void> _fetchITunesAlbumArt(String query) async {
    try {
      final uri = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=1');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          final art100 = data['results'][0]['artworkUrl100']?.toString();
          if (art100 != null && art100.isNotEmpty) {
            // Convertir carátula de 100x100 a alta definición 600x600 px
            final art600 = art100.replaceAll('100x100bb', '600x600bb');
            _albumArtUrlSubject.add(art600);

            // Actualizar notificación multimedia de Android
            if (mediaItem.value != null) {
              mediaItem.add(mediaItem.value!.copyWith(
                subtitle: query,
                artUri: Uri.tryParse(art600),
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error buscando carátula en iTunes API: $e');
    }
  }

  /// Si la señal de la radio se corta por micro-caídas de red, reintenta reconectar automáticamente
  void _handleStreamDrop() {
    if (_isManualStop || currentStation == null) return;

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      debugPrint('Señal caída. Reintento de reconexión $_reconnectAttempts/$_maxReconnectAttempts para ${currentStation!.name}...');
      Future.delayed(Duration(seconds: _reconnectAttempts * 2), () {
        if (currentStation != null && !_isManualStop) {
          playStation(currentStation!, updateQueue: false);
        }
      });
    } else {
      _errorSubject.add('Conexión inestable con el servidor de esta radio.');
      stop();
    }
  }

  /// Establece la lista de emisoras activa para navegar con Siguiente / Anterior.
  void setQueue(List<RadioStation> stations, {int initialIndex = 0}) {
    _queueStations = List.from(stations);
    _currentIndex = initialIndex;
  }

  /// Inicia la reproducción de una estación.
  Future<void> playStation(RadioStation station, {bool updateQueue = true}) async {
    _isManualStop = false;
    _errorSubject.add(null);
    _nowPlayingTrackSubject.add(null);
    _albumArtUrlSubject.add(station.favicon.isNotEmpty ? station.favicon : null);
    _currentStationSubject.add(station);

    if (updateQueue) {
      _reconnectAttempts = 0;
      if (!_queueStations.contains(station)) {
        _queueStations.add(station);
      }
      _currentIndex = _queueStations.indexOf(station);
    }

    final item = MediaItem(
      id: station.stationUuid,
      title: station.name,
      artist: station.displayLocation,
      album: station.tags.isNotEmpty ? station.tags : 'Radio World',
      artUri: station.favicon.isNotEmpty ? Uri.tryParse(station.favicon) : null,
      extras: station.toJson(),
    );
    mediaItem.add(item);

    try {
      await _player.stop();
      final uri = Uri.tryParse(station.urlResolved);
      if (uri == null) {
        throw Exception('URL no válida');
      }

      await _player
          .setAudioSource(AudioSource.uri(uri), preload: true)
          .timeout(const Duration(seconds: 10));

      await _player.play();
      _reconnectAttempts = 0;
    } catch (e) {
      debugPrint('Timeout o error al sintonizar ${station.name}: $e');
      _handleStreamDrop();
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_queueStations.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _queueStations.length;
    final nextStation = _queueStations[_currentIndex];
    await playStation(nextStation, updateQueue: false);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queueStations.isEmpty) return;
    _currentIndex = (_currentIndex - 1 + _queueStations.length) % _queueStations.length;
    final prevStation = _queueStations[_currentIndex];
    await playStation(prevStation, updateQueue: false);
  }

  /// Inicia o cancela el temporizador de apagado automático.
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _countdownTicker?.cancel();

    if (duration == null || duration.inSeconds <= 0) {
      _sleepTimerRemainingSubject.add(null);
      return;
    }

    _sleepTimerRemainingSubject.add(duration);

    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = _sleepTimerRemainingSubject.value;
      if (current == null || current.inSeconds <= 1) {
        timer.cancel();
      } else {
        _sleepTimerRemainingSubject.add(current - const Duration(seconds: 1));
      }
    });

    _sleepTimer = Timer(duration, () {
      cancelSleepTimer();
      stop();
      _errorSubject.add('Radio apagada por el temporizador.');
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _countdownTicker?.cancel();
    _sleepTimer = null;
    _countdownTicker = null;
    _sleepTimerRemainingSubject.add(null);
  }

  @override
  Future<void> play() async {
    _isManualStop = false;
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _isManualStop = true;
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    _isManualStop = true;
    await _player.stop();
    await super.stop();
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final processingState = _getProcessingState();

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.playPause,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  AudioProcessingState _getProcessingState() {
    switch (_player.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  Stream<ProcessingState> get processingStateStream => _player.processingStateStream;
  Stream<bool> get playingStream => _player.playingStream;

  void dispose() {
    cancelSleepTimer();
    _player.dispose();
    _currentStationSubject.close();
    _nowPlayingTrackSubject.close();
    _albumArtUrlSubject.close();
    _errorSubject.close();
    _sleepTimerRemainingSubject.close();
  }
}
