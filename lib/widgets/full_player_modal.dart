import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import '../models/radio_station.dart';
import '../services/favorites_service.dart';
import '../services/radio_audio_handler.dart';

/// Modal Full-Screen estilo Spotify / Apple Music que se despliega al tocar el reproductor flotante.
class FullPlayerModal extends StatefulWidget {
  final RadioAudioHandler audioHandler;

  const FullPlayerModal({super.key, required this.audioHandler});

  static void show(BuildContext context, RadioAudioHandler audioHandler) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FullPlayerModal(audioHandler: audioHandler),
    );
  }

  @override
  State<FullPlayerModal> createState() => _FullPlayerModalState();
}

class _FullPlayerModalState extends State<FullPlayerModal> {
  final FavoritesService _favs = FavoritesService();
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _checkFavStatus();
  }

  void _checkFavStatus() {
    final station = widget.audioHandler.currentStation;
    if (station != null) {
      setState(() {
        _isFav = _favs.isFavorite(station.stationUuid);
      });
    }
  }

  Future<void> _toggleFav() async {
    final station = widget.audioHandler.currentStation;
    if (station != null) {
      final added = await _favs.toggleFavorite(station);
      if (mounted) {
        setState(() {
          _isFav = added;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added
                  ? '❤️ Añadida a Favoritas: ${station.name}'
                  : 'Removida de Favoritas: ${station.name}',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF0F172A),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final station = widget.audioHandler.currentStation;
    if (station == null) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F19),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF030712),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ─── 1. Header con botón Minimizar ───────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white, size: 32),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Column(
                    children: [
                      Text(
                        'REPRODUCIENDO EN VIVO',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00FF88),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            station.country.isNotEmpty ? station.country : 'Mundo',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isFav ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                      size: 26,
                    ),
                    onPressed: _toggleFav,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ─── 2. Carátula Gigante Estilo Spotify ──────────────────────
            StreamBuilder<String?>(
              stream: widget.audioHandler.albumArtUrlStream,
              builder: (context, snapshot) {
                final artUrl = snapshot.data ??
                    (station.favicon.isNotEmpty ? station.favicon : null);

                return Container(
                  width: screenHeight * 0.35,
                  height: screenHeight * 0.35,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFF0F172A),
                    border: Border.all(
                      color: const Color(0xFF00FF88).withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.7),
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 15),
                      ),
                      BoxShadow(
                        color: const Color(0xFF00FF88).withOpacity(0.15),
                        blurRadius: 25,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: artUrl != null && artUrl.isNotEmpty
                      ? Image.network(
                          artUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.music_note_rounded,
                            color: Color(0xFF00FF88),
                            size: 80,
                          ),
                        )
                      : const Icon(
                          Icons.radio_rounded,
                          color: Color(0xFF00FF88),
                          size: 80,
                        ),
                );
              },
            ),

            const Spacer(),

            // ─── 3. Título de Canción y Emisora ─────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  // Título de la canción en vivo
                  StreamBuilder<String?>(
                    stream: widget.audioHandler.nowPlayingTrackStream,
                    builder: (context, trackSnapshot) {
                      final track = trackSnapshot.data;
                      final hasTrack = track != null && track.isNotEmpty;

                      return Text(
                        hasTrack ? track : station.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  // Nombre de la emisora y ciudad
                  StreamBuilder<String?>(
                    stream: widget.audioHandler.nowPlayingTrackStream,
                    builder: (context, trackSnapshot) {
                      final track = trackSnapshot.data;
                      final hasTrack = track != null && track.isNotEmpty;

                      return Text(
                        hasTrack
                            ? '${station.name} · ${station.displayLocation}'
                            : station.displayLocation,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF38BDF8),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── 4. Indicador / Barra de Estado de Transmisión En Vivo ───
            StreamBuilder<ProcessingState>(
              stream: widget.audioHandler.processingStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data ?? ProcessingState.idle;
                final bool isBuffering = state == ProcessingState.loading ||
                    state == ProcessingState.buffering;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      if (isBuffering)
                        const LinearProgressIndicator(
                          backgroundColor: Color(0xFF1E293B),
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
                        )
                      else
                        Container(
                          height: 2,
                          color: const Color(0xFF00FF88).withOpacity(0.4),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isBuffering ? 'Cargando stream...' : 'EN VIVO 🔴',
                            style: GoogleFonts.outfit(
                              color: isBuffering
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF00FF88),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (station.bitrate > 0)
                            Text(
                              '${station.bitrate} kbps HD',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ─── 5. Controles Principales Estilo Spotify ────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Botón Temporizador
                  StreamBuilder<Duration?>(
                    stream: widget.audioHandler.sleepTimerRemainingStream,
                    builder: (context, snapshot) {
                      final hasTimer = snapshot.data != null;
                      return IconButton(
                        iconSize: 28,
                        icon: Icon(
                          hasTimer ? Icons.timer_rounded : Icons.timer_outlined,
                          color: hasTimer ? const Color(0xFF00FF88) : const Color(0xFF64748B),
                        ),
                        onPressed: () {
                          // Abre opciones de temporizador
                        },
                      );
                    },
                  ),

                  // Botón Anterior
                  IconButton(
                    iconSize: 42,
                    icon: const Icon(Icons.skip_previous_rounded,
                        color: Colors.white),
                    onPressed: () => widget.audioHandler.skipToPrevious(),
                  ),

                  // Botón Gigante Play / Pause
                  StreamBuilder<bool>(
                    stream: widget.audioHandler.playingStream,
                    builder: (context, playingSnapshot) {
                      final bool isPlaying = playingSnapshot.data ?? false;

                      return Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FF88).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: IconButton(
                          iconSize: 40,
                          icon: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            if (isPlaying) {
                              widget.audioHandler.pause();
                            } else {
                              widget.audioHandler.play();
                            }
                          },
                        ),
                      );
                    },
                  ),

                  // Botón Siguiente
                  IconButton(
                    iconSize: 42,
                    icon: const Icon(Icons.skip_next_rounded,
                        color: Colors.white),
                    onPressed: () => widget.audioHandler.skipToNext(),
                  ),

                  // Botón Favorito
                  IconButton(
                    iconSize: 28,
                    icon: Icon(
                      _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isFav ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                    ),
                    onPressed: _toggleFav,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
