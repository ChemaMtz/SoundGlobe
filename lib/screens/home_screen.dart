import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/radio_station.dart';
import '../services/favorites_service.dart';
import '../services/radio_api_service.dart';
import '../services/radio_audio_handler.dart';
import '../widgets/floating_player.dart';

class HomeScreen extends StatefulWidget {
  final RadioAudioHandler audioHandler;
  const HomeScreen({super.key, required this.audioHandler});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RadioApiService _api = RadioApiService();
  final FavoritesService _favs = FavoritesService();
  final TextEditingController _searchCtrl = TextEditingController();

  Map<String, List<RadioStation>> _byCountry = {};
  final Set<String> _expanded = {};
  Set<String> _favUuids = {};

  bool _loading = true;
  String _searchQuery = '';
  String _selectedCategory = 'Todos';

  final List<String> _categories = [
    'Todos',
    '❤️ Favoritas',
    '🕐 Recientes',
    '🎧 HD (≥128k)',
    'Pop',
    'Rock',
    'Noticias',
    'Salsa',
    'Reggaeton',
    'Jazz',
    'Deportes',
  ];

  @override
  void initState() {
    super.initState();
    _initFavs();
    _loadStations();
    widget.audioHandler.errorStream.listen((msg) {
      if (msg != null && mounted) {
        _showSnackbar(msg);
      }
    });
  }

  Future<void> _initFavs() async {
    await _favs.init();
    if (mounted) {
      setState(() {
        _favUuids = _favs.getFavoriteUuids();
      });
    }
  }

  Future<void> _loadStations({bool forceRefresh = false}) async {
    setState(() => _loading = true);
    final stations = await _api.getTopGlobalStations(
      limit: 5000,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;

    final map = <String, List<RadioStation>>{};
    for (final s in stations) {
      final country = s.country.trim().isEmpty ? 'Internacional' : s.country.trim();
      map.putIfAbsent(country, () => []).add(s);
    }
    for (final k in map.keys) {
      map[k]!.sort((a, b) => b.votes.compareTo(a.votes));
    }

    final sortedKeys = map.keys.toList();
    sortedKeys.sort((a, b) {
      if (a.toLowerCase().contains('mexico') || a.toLowerCase().contains('méxico')) return -1;
      if (b.toLowerCase().contains('mexico') || b.toLowerCase().contains('méxico')) return 1;
      return (map[b]?.length ?? 0).compareTo(map[a]?.length ?? 0);
    });

    final sorted = <String, List<RadioStation>>{};
    for (final k in sortedKeys) {
      sorted[k] = map[k]!;
    }

    setState(() {
      _byCountry = sorted;
      _loading = false;
      for (final k in sorted.keys) {
        if (k.toLowerCase().contains('mexico') || k.toLowerCase().contains('méxico')) {
          _expanded.add(k);
          break;
        }
      }
    });
  }

  void _playStation(RadioStation station, [List<RadioStation>? playlist, int index = 0]) {
    if (playlist != null && playlist.isNotEmpty) {
      widget.audioHandler.setQueue(playlist, initialIndex: index);
    }
    widget.audioHandler.playStation(station);
    _favs.addRecent(station);
    setState(() {});
  }

  Future<void> _toggleFavorite(RadioStation station) async {
    final added = await _favs.toggleFavorite(station);
    setState(() {
      _favUuids = _favs.getFavoriteUuids();
    });
    _showSnackbar(added
        ? '❤️ Añadida a Favoritas: ${station.name}'
        : 'Removida de Favoritas: ${station.name}');
  }

  Map<String, List<RadioStation>> get _filtered {
    if (_selectedCategory == '❤️ Favoritas') {
      final favList = _favs.getFavoriteStations();
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matched = favList
            .where((s) =>
                s.name.toLowerCase().contains(q) ||
                s.country.toLowerCase().contains(q) ||
                s.tags.toLowerCase().contains(q))
            .toList();
        return matched.isNotEmpty ? {'Mis Favoritas ❤️': matched} : {};
      }
      return favList.isNotEmpty ? {'Mis Favoritas ❤️': favList} : {};
    }

    if (_selectedCategory == '🕐 Recientes') {
      final recents = _favs.getRecentStations();
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matched = recents
            .where((s) =>
                s.name.toLowerCase().contains(q) ||
                s.country.toLowerCase().contains(q) ||
                s.tags.toLowerCase().contains(q))
            .toList();
        return matched.isNotEmpty ? {'Escuchadas Recientemente 🕐': matched} : {};
      }
      return recents.isNotEmpty ? {'Escuchadas Recientemente 🕐': recents} : {};
    }

    final result = <String, List<RadioStation>>{};
    final queryLower = _searchQuery.toLowerCase();

    for (final entry in _byCountry.entries) {
      List<RadioStation> list = entry.value;

      // Filtro por categoría
      if (_selectedCategory == '🎧 HD (≥128k)') {
        list = list.where((s) => s.bitrate >= 128).toList();
      } else if (_selectedCategory != 'Todos') {
        final catLower = _selectedCategory.toLowerCase();
        list = list.where((s) => s.tags.toLowerCase().contains(catLower)).toList();
      }

      // Filtro por texto de búsqueda
      if (queryLower.isNotEmpty) {
        final countryMatches = entry.key.toLowerCase().contains(queryLower);
        if (!countryMatches) {
          list = list.where((s) =>
              s.name.toLowerCase().contains(queryLower) ||
              s.tags.toLowerCase().contains(queryLower)).toList();
        }
      }

      if (list.isNotEmpty) {
        result[entry.key] = list;
      }
    }

    return result;
  }

  String _countryFlag(String country) {
    final flags = {
      'mexico': '🇲🇽', 'méxico': '🇲🇽',
      'united states': '🇺🇸', 'the united states of america': '🇺🇸',
      'spain': '🇪🇸', 'españa': '🇪🇸',
      'colombia': '🇨🇴', 'argentina': '🇦🇷', 'brazil': '🇧🇷', 'brasil': '🇧🇷',
      'germany': '🇩🇪', 'france': '🇫🇷', 'italy': '🇮🇹',
      'united kingdom': '🇬🇧', 'the united kingdom of great britain and northern ireland': '🇬🇧',
      'canada': '🇨🇦', 'australia': '🇦🇺', 'japan': '🇯🇵',
      'china': '🇨🇳', 'india': '🇮🇳', 'russia': '🇷🇺', 'the russian federation': '🇷🇺',
      'netherlands': '🇳🇱', 'the netherlands': '🇳🇱',
      'austria': '🇦🇹', 'switzerland': '🇨🇭', 'belgium': '🇧🇪',
      'poland': '🇵🇱', 'portugal': '🇵🇹', 'venezuela': '🇻🇪',
      'chile': '🇨🇱', 'peru': '🇵🇪', 'ecuador': '🇪🇨',
      'uruguay': '🇺🇾', 'paraguay': '🇵🇾', 'bolivia': '🇧🇴',
      'cuba': '🇨🇺', 'dominican republic': '🇩🇴', 'puerto rico': '🇵🇷',
      'turkey': '🇹🇷', 'greece': '🇬🇷', 'sweden': '🇸🇪',
      'norway': '🇳🇴', 'denmark': '🇩🇰', 'finland': '🇫🇮',
      'south africa': '🇿🇦', 'nigeria': '🇳🇬', 'egypt': '🇪🇬',
      'international': '🌐', 'internacional': '🌐',
      'mis favoritas ❤️': '❤️',
      'escuchadas recientemente 🕐': '🕐',
    };
    final key = country.toLowerCase().trim();
    return flags[key] ?? '📻';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildCategoryFilterBar(),
          Expanded(
            child: _loading
                ? _buildLoader()
                : _buildCountryList(),
          ),
        ],
      ),
      bottomNavigationBar: FloatingPlayer(
        audioHandler: widget.audioHandler,
        onOpenStationList: () {},
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0F172A),
            const Color(0xFF030712).withOpacity(0),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00FF88), Color(0xFF38BDF8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FF88).withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.radio, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RADIO WORLD',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      )),
                  Text('${_byCountry.length} países · ${_byCountry.values.fold(0, (s, l) => s + l.length)} emisoras',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF38BDF8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      )),
                ],
              ),
              const Spacer(),
              StreamBuilder<Duration?>(
                stream: widget.audioHandler.sleepTimerRemainingStream,
                builder: (context, snapshot) {
                  final hasTimer = snapshot.data != null;
                  return IconButton(
                    icon: Icon(
                      hasTimer ? Icons.timer_rounded : Icons.timer_outlined,
                      color: hasTimer ? const Color(0xFF00FF88) : const Color(0xFF94A3B8),
                    ),
                    onPressed: _showSleepTimerBottomSheet,
                    tooltip: 'Temporizador de apagado',
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00FF88)),
                onPressed: () {
                  _showSnackbar('Actualizando catálogo desde la red...');
                  _loadStations(forceRefresh: true);
                },
                tooltip: 'Actualizar emisoras',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSleepTimerBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StreamBuilder<Duration?>(
          stream: widget.audioHandler.sleepTimerRemainingStream,
          builder: (context, snapshot) {
            final activeDuration = snapshot.data;
            final options = [
              {'label': '15 minutos', 'minutes': 15},
              {'label': '30 minutos', 'minutes': 30},
              {'label': '45 minutos', 'minutes': 45},
              {'label': '60 minutos (1 hora)', 'minutes': 60},
              {'label': '90 minutos (1.5 horas)', 'minutes': 90},
            ];

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: Color(0xFF00FF88), size: 24),
                            const SizedBox(width: 10),
                            Text(
                              'Apagado Automático',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (activeDuration != null)
                          TextButton(
                            onPressed: () {
                              widget.audioHandler.setSleepTimer(null);
                              Navigator.pop(context);
                              _showSnackbar('Temporizador desactivado');
                            },
                            child: Text(
                              'Desactivar',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFEF4444),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (activeDuration != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FF88).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF00FF88), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_filled, color: Color(0xFF00FF88), size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'La radio se apagará en: ${_formatDuration(activeDuration)}',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00FF88),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ...options.map((opt) {
                      final mins = opt['minutes'] as int;
                      final label = opt['label'] as String;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.alarm, color: Color(0xFF38BDF8), size: 20),
                        title: Text(
                          label,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF475569)),
                        onTap: () {
                          widget.audioHandler.setSleepTimer(Duration(minutes: mins));
                          Navigator.pop(context);
                          _showSnackbar('La radio se apagará en $label');
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF00FF88), width: 1),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF1E293B),
            width: 1.5,
          ),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Buscar país, emisora o género...',
            hintStyle: GoogleFonts.outfit(
                color: const Color(0xFF475569), fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Color(0xFF475569), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF475569), size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterBar() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory == cat;

          return ChoiceChip(
            label: Text(cat),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                _selectedCategory = cat;
              });
            },
            labelStyle: GoogleFonts.outfit(
              color: isSelected ? const Color(0xFF030712) : Colors.white,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
            selectedColor: const Color(0xFF00FF88),
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF00FF88)
                    : const Color(0xFF1E293B),
                width: 1,
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Cargando emisoras del mundo...',
              style: GoogleFonts.outfit(
                  color: const Color(0xFF64748B), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCountryList() {
    final data = _filtered;
    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radio_outlined, color: Color(0xFF334155), size: 48),
            const SizedBox(height: 12),
            Text(
              _selectedCategory == '❤️ Favoritas'
                  ? 'Aún no tienes emisoras en Favoritas.\nToca el corazón ❤️ en cualquier emisora para guardarla.'
                  : _selectedCategory == '🕐 Recientes'
                      ? 'Aún no has escuchado emisoras en esta sesión.'
                      : 'Sin resultados para "$_searchQuery"',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  color: const Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 8),
      itemCount: data.keys.length,
      itemBuilder: (ctx, i) {
        final country = data.keys.elementAt(i);
        final stations = data[country]!;
        final isExpanded = _expanded.contains(country) ||
            _searchQuery.isNotEmpty ||
            _selectedCategory != 'Todos';

        return _CountrySection(
          flag: _countryFlag(country),
          country: country,
          stations: stations,
          isExpanded: isExpanded,
          currentStation: widget.audioHandler.currentStation,
          favUuids: _favUuids,
          onToggle: () {
            setState(() {
              if (_expanded.contains(country)) {
                _expanded.remove(country);
              } else {
                _expanded.add(country);
              }
            });
          },
          onSelectStation: (st, pl, idx) => _playStation(st, pl, idx),
          onToggleFavorite: _toggleFavorite,
        );
      },
    );
  }
}

class _CountrySection extends StatefulWidget {
  final String flag;
  final String country;
  final List<RadioStation> stations;
  final bool isExpanded;
  final RadioStation? currentStation;
  final Set<String> favUuids;
  final VoidCallback onToggle;
  final void Function(RadioStation station, List<RadioStation> playlist, int index) onSelectStation;
  final void Function(RadioStation) onToggleFavorite;

  const _CountrySection({
    super.key,
    required this.flag,
    required this.country,
    required this.stations,
    required this.isExpanded,
    required this.currentStation,
    required this.favUuids,
    required this.onToggle,
    required this.onSelectStation,
    required this.onToggleFavorite,
  });

  @override
  State<_CountrySection> createState() => _CountrySectionState();
}

class _CountrySectionState extends State<_CountrySection> {
  int _visibleLimit = 25;

  @override
  Widget build(BuildContext context) {
    final total = widget.stations.length;
    final visibleStations = widget.stations.take(_visibleLimit).toList();

    return Column(
      children: [
        InkWell(
          onTap: widget.onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF1E293B),
                  width: widget.isExpanded ? 0 : 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(widget.flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(widget.country,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      )),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF1E293B), width: 1),
                  ),
                  child: Text('$total',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      )),
                ),
                const SizedBox(width: 10),
                Icon(
                  widget.isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF475569),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        if (widget.isExpanded)
          Column(
            children: [
              ...visibleStations.asMap().entries.map((entry) {
                final idx = entry.key;
                final s = entry.value;
                return _StationTile(
                  station: s,
                  isPlaying: widget.currentStation?.stationUuid == s.stationUuid,
                  isFavorite: widget.favUuids.contains(s.stationUuid),
                  onTap: () => widget.onSelectStation(s, widget.stations, idx),
                  onFavoriteTap: () => widget.onToggleFavorite(s),
                );
              }),
              if (total > _visibleLimit)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _visibleLimit += 50;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF00FF88).withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_circle_outline_rounded,
                              color: Color(0xFF00FF88), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Ver más emisoras (+${total - _visibleLimit} restantes)',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF00FF88),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (total > 25 && _visibleLimit > 25)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _visibleLimit = 25;
                      });
                    },
                    icon: const Icon(Icons.keyboard_arrow_up_rounded,
                        color: Color(0xFF64748B), size: 18),
                    label: Text(
                      'Mostrar menos',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              const Divider(
                  color: Color(0xFF1E293B), height: 1, thickness: 1),
            ],
          ),
      ],
    );
  }
}

class _StationTile extends StatelessWidget {
  final RadioStation station;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  const _StationTile({
    required this.station,
    required this.isPlaying,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: isPlaying
              ? const Color(0xFF00FF88).withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPlaying
                ? const Color(0xFF00FF88).withOpacity(0.4)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              _StationAvatar(favicon: station.favicon, isPlaying: isPlaying),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
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
                    if (station.tags.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        station.tagList.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFavorite ? const Color(0xFFEF4444) : const Color(0xFF475569),
                  size: 20,
                ),
                onPressed: onFavoriteTap,
                tooltip: isFavorite ? 'Remover de favoritas' : 'Guardar en favoritas',
              ),
              if (station.bitrate > 0)
                Text(
                  '${station.bitrate}k',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF334155),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(width: 6),
              if (isPlaying)
                const _PlayingIndicator()
              else
                const Icon(Icons.play_circle_outline_rounded,
                    color: Color(0xFF334155), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationAvatar extends StatelessWidget {
  final String favicon;
  final bool isPlaying;

  const _StationAvatar({required this.favicon, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF0F172A),
        border: Border.all(
          color: isPlaying
              ? const Color(0xFF00FF88).withOpacity(0.5)
              : const Color(0xFF1E293B),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: favicon.isNotEmpty
          ? Image.network(
              favicon,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.radio_rounded,
                color: Color(0xFF475569),
                size: 22,
              ),
            )
          : const Icon(Icons.radio_rounded,
              color: Color(0xFF475569), size: 22),
    );
  }
}

class _PlayingIndicator extends StatefulWidget {
  const _PlayingIndicator();

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: const Icon(
        Icons.equalizer_rounded,
        color: Color(0xFF00FF88),
        size: 22,
      ),
    );
  }
}
