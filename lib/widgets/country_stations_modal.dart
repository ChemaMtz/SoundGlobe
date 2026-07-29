import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/radio_station.dart';
import '../services/favorites_service.dart';
import '../services/radio_audio_handler.dart';

/// Modal desplegable para ver y buscar TODAS las emisoras de un país específico.
class CountryStationsModal extends StatefulWidget {
  final String country;
  final String flag;
  final List<RadioStation> stations;
  final RadioAudioHandler audioHandler;
  final void Function(RadioStation station, List<RadioStation> playlist, int index) onSelectStation;

  const CountryStationsModal({
    super.key,
    required this.country,
    required this.flag,
    required this.stations,
    required this.audioHandler,
    required this.onSelectStation,
  });

  static void show({
    required BuildContext context,
    required String country,
    required String flag,
    required List<RadioStation> stations,
    required RadioAudioHandler audioHandler,
    required void Function(RadioStation station, List<RadioStation> playlist, int index) onSelectStation,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CountryStationsModal(
        country: country,
        flag: flag,
        stations: stations,
        audioHandler: audioHandler,
        onSelectStation: onSelectStation,
      ),
    );
  }

  @override
  State<CountryStationsModal> createState() => _CountryStationsModalState();
}

class _CountryStationsModalState extends State<CountryStationsModal> {
  final FavoritesService _favs = FavoritesService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  Set<String> _favUuids = {};

  @override
  void initState() {
    super.initState();
    _favUuids = _favs.getFavoriteUuids();
  }

  List<RadioStation> get _filteredStations {
    if (_query.trim().isEmpty) return widget.stations;
    final q = _query.toLowerCase().trim();
    return widget.stations.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.state.toLowerCase().contains(q) ||
          s.tags.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _toggleFav(RadioStation s) async {
    final added = await _favs.toggleFavorite(s);
    if (mounted) {
      setState(() {
        _favUuids = _favs.getFavoriteUuids();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added ? '❤️ Añadida a Favoritas: ${s.name}' : 'Removida de Favoritas: ${s.name}',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF0F172A),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final stationsList = _filteredStations;

    return Container(
      height: screenHeight * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F19),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ─── 1. Header con Bandera, País y Cantidad de Emisoras ─────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(widget.flag, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.country,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${widget.stations.length} emisoras disponibles',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF00FF88),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── 2. Buscador interno del País ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar emisora o ciudad de ${widget.country}...',
                    hintStyle: GoogleFonts.outfit(
                        color: const Color(0xFF475569), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF475569), size: 18),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Color(0xFF475569), size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // ─── 3. Lista completa de emisoras del País ────────────────────
            Expanded(
              child: stationsList.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron emisoras en ${widget.country} para "$_query"',
                        style: GoogleFonts.outfit(
                            color: const Color(0xFF64748B), fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24, top: 4),
                      itemCount: stationsList.length,
                      itemBuilder: (context, index) {
                        final s = stationsList[index];
                        final isPlaying =
                            widget.audioHandler.currentStation?.stationUuid == s.stationUuid;
                        final isFav = _favUuids.contains(s.stationUuid);

                        return InkWell(
                          onTap: () {
                            widget.onSelectStation(s, stationsList, index);
                            Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? const Color(0xFF00FF88).withOpacity(0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isPlaying
                                    ? const Color(0xFF00FF88).withOpacity(0.4)
                                    : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Avatar / Favicon
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: const Color(0xFF0F172A),
                                    border: Border.all(
                                      color: isPlaying
                                          ? const Color(0xFF00FF88)
                                          : const Color(0xFF1E293B),
                                      width: 1.2,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: s.favicon.isNotEmpty
                                      ? Image.network(
                                          s.favicon,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.radio_rounded,
                                            color: Color(0xFF475569),
                                            size: 20,
                                          ),
                                        )
                                      : const Icon(Icons.radio_rounded,
                                          color: Color(0xFF475569), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          color: isPlaying
                                              ? const Color(0xFF00FF88)
                                              : Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        s.displayLocation.isNotEmpty
                                            ? s.displayLocation
                                            : (s.tags.isNotEmpty ? s.tags : widget.country),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF64748B),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isFav
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: isFav
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF475569),
                                    size: 20,
                                  ),
                                  onPressed: () => _toggleFav(s),
                                ),
                                if (isPlaying)
                                  const Icon(Icons.equalizer_rounded,
                                      color: Color(0xFF00FF88), size: 22)
                                else
                                  const Icon(Icons.play_circle_outline_rounded,
                                      color: Color(0xFF334155), size: 22),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
