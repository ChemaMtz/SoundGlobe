import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/radio_station.dart';

/// Modal estilo BottomSheet para listar emisoras cercanas a la coordenada seleccionada
/// y permitir seleccionar otra estación en la misma región.
class StationListSheet extends StatelessWidget {
  final List<RadioStation> stations;
  final RadioStation? activeStation;
  final ValueChanged<RadioStation> onSelectStation;
  final String title;

  const StationListSheet({
    super.key,
    required this.stations,
    this.activeStation,
    required this.onSelectStation,
    this.title = 'EMISORAS CERCANAS',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Indicador del BottomSheet
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF475569),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Título del Sheet
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF38BDF8),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  '${stations.length} ESTACIONES',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1E293B), height: 1),
          // Lista de Estaciones
          Expanded(
            child: stations.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron emisoras en este radio.',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 15,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: stations.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: Color(0xFF1E293B),
                      height: 1,
                      indent: 72,
                    ),
                    itemBuilder: (context, index) {
                      final station = stations[index];
                      final bool isSelected =
                          activeStation?.stationUuid == station.stationUuid;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 4,
                        ),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? const Color(0xFF00FF88).withOpacity(0.15)
                                : const Color(0xFF1E293B),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00FF88)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.radio,
                              color: isSelected
                                  ? const Color(0xFF00FF88)
                                  : const Color(0xFF94A3B8),
                              size: 22,
                            ),
                          ),
                        ),
                        title: Text(
                          station.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color:
                                isSelected ? const Color(0xFF00FF88) : Colors.white,
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          station.displayLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                        ),
                        trailing: station.bitrate > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${station.bitrate} kbps',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF64748B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          onSelectStation(station);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Muestra el modal en pantalla.
  static void show({
    required BuildContext context,
    required List<RadioStation> stations,
    RadioStation? activeStation,
    required ValueChanged<RadioStation> onSelectStation,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StationListSheet(
        stations: stations,
        activeStation: activeStation,
        onSelectStation: onSelectStation,
      ),
    );
  }
}
