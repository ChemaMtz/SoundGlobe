import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import '../models/radio_station.dart';
import '../services/radio_audio_handler.dart';

/// Reproductor flotante estilo Glassmorphic ubicado en la parte inferior.
/// Muestra la emisora activa, ubicación, estado de buffering y botones Play/Pause.
class FloatingPlayer extends StatelessWidget {
  final RadioAudioHandler audioHandler;
  final VoidCallback? onOpenStationList;

  const FloatingPlayer({
    super.key,
    required this.audioHandler,
    this.onOpenStationList,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RadioStation?>(
      stream: audioHandler.currentStationStream,
      builder: (context, stationSnapshot) {
        final station = stationSnapshot.data;

        if (station == null) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 8,
            top: 8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF00FF88).withOpacity(0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF00FF88).withOpacity(0.08),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              // Indicador circular de EN VIVO (Live Radar)
              _buildLiveIndicator(),
              const SizedBox(width: 14),
              
              // Título y Ciudad de la emisora
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      station.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 13,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            station.displayLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Indicador de temporizador de apagado activo
              StreamBuilder<Duration?>(
                stream: audioHandler.sleepTimerRemainingStream,
                builder: (context, timerSnapshot) {
                  final remaining = timerSnapshot.data;
                  if (remaining == null) return const SizedBox.shrink();

                  String format(Duration d) {
                    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
                    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
                    final hrs = d.inHours;
                    return hrs > 0 ? '$hrs:$mins:$secs' : '$mins:$secs';
                  }

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00FF88).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 13, color: Color(0xFF00FF88)),
                        const SizedBox(width: 4),
                        Text(
                          format(remaining),
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF00FF88),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(width: 4),

              // Botón de Play / Pause / Loading
              _buildPlayPauseButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLiveIndicator() {
    return StreamBuilder<ProcessingState>(
      stream: audioHandler.processingStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data ?? ProcessingState.idle;
        final bool isBuffering =
            state == ProcessingState.loading || state == ProcessingState.buffering;

        return Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF00FF88), Color(0xFF00B8D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FF88).withOpacity(0.35),
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: isBuffering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF030712)),
                    ),
                  )
                : const Icon(
                    Icons.radio,
                    color: Color(0xFF030712),
                    size: 24,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildPlayPauseButton() {
    return StreamBuilder<bool>(
      stream: audioHandler.playingStream,
      builder: (context, playingSnapshot) {
        final bool isPlaying = playingSnapshot.data ?? false;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded,
                  color: Color(0xFF94A3B8), size: 24),
              onPressed: () => audioHandler.skipToPrevious(),
              tooltip: 'Emisora anterior',
            ),
            Material(
              color: const Color(0xFF1E293B),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  if (isPlaying) {
                    audioHandler.pause();
                  } else {
                    audioHandler.play();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded,
                  color: Color(0xFF94A3B8), size: 24),
              onPressed: () => audioHandler.skipToNext(),
              tooltip: 'Siguiente emisora',
            ),
          ],
        );
      },
    );
  }
}
