import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../models/radio_station.dart';

/// Manejador de audio que integra just_audio, audio_service y temporizador de apagado automático.
class RadioAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  final _currentStationSubject = BehaviorSubject<RadioStation?>.seeded(null);
  Stream<RadioStation?> get currentStationStream => _currentStationSubject.stream;
  RadioStation? get currentStation => _currentStationSubject.value;

  final _errorSubject = BehaviorSubject<String?>.seeded(null);
  Stream<String?> get errorStream => _errorSubject.stream;

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
      _errorSubject.add('No se pudo reproducir este stream.');
      stop();
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        stop();
      }
    });
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

  /// Inicia la reproducción de forma asíncrona incorporando un timeout de 8 segundos.
  Future<void> playStation(RadioStation station) async {
    _errorSubject.add(null);
    _currentStationSubject.add(station);

    final item = MediaItem(
      id: station.stationUuid,
      title: station.name,
      artist: station.displayLocation,
      album: station.tags.isNotEmpty ? station.tags : 'Radio Garden',
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
          .setAudioSource(AudioSource.uri(uri))
          .timeout(const Duration(seconds: 8));
      await _player.play();
    } catch (e) {
      debugPrint('Timeout o error al sintonizar ${station.name}: $e');
      _errorSubject.add('Stream no disponible, intenta con otra emisora.');
      await stop();
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final processingState = _getProcessingState();

    playbackState.add(PlaybackState(
      controls: [
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.playPause,
      },
      androidCompactActionIndices: const [0, 1],
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
    _errorSubject.close();
    _sleepTimerRemainingSubject.close();
  }
}
