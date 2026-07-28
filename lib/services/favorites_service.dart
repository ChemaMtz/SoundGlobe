import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/radio_station.dart';

/// Servicio para persistir en almacenamiento local (SharedPreferences):
/// 1. Estaciones Favoritas (❤️)
/// 2. Historial de Estaciones Escuchadas Recientemente (🕐)
class FavoritesService {
  static const String _keyFavorites = 'favorite_stations_v1';
  static const String _keyRecents = 'recent_stations_v1';

  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ────────────── FAVORITOS ──────────────

  /// Retorna el conjunto de UUIDs de las emisoras guardadas como favoritas.
  Set<String> getFavoriteUuids() {
    final list = _prefs?.getStringList(_keyFavorites) ?? [];
    return list.toSet();
  }

  /// Retorna los objetos completos de emisoras favoritas.
  List<RadioStation> getFavoriteStations() {
    final jsonList = _prefs?.getStringList('${_keyFavorites}_data') ?? [];
    return jsonList
        .map((str) {
          try {
            return RadioStation.fromJson(json.decode(str));
          } catch (_) {
            return null;
          }
        })
        .whereType<RadioStation>()
        .toList();
  }

  bool isFavorite(String uuid) {
    return getFavoriteUuids().contains(uuid);
  }

  Future<bool> toggleFavorite(RadioStation station) async {
    await init();
    final uuids = getFavoriteUuids();
    final stations = getFavoriteStations();

    final isFav = uuids.contains(station.stationUuid);

    if (isFav) {
      uuids.remove(station.stationUuid);
      stations.removeWhere((s) => s.stationUuid == station.stationUuid);
    } else {
      uuids.add(station.stationUuid);
      stations.insert(0, station);
    }

    await _prefs?.setStringList(_keyFavorites, uuids.toList());
    await _prefs?.setStringList(
      '${_keyFavorites}_data',
      stations.map((s) => json.encode(s.toJson())).toList(),
    );

    return !isFav;
  }

  // ────────────── RECIENTES ──────────────

  /// Agrega una emisora al historial de escuchadas recientemente.
  Future<void> addRecent(RadioStation station) async {
    await init();
    final recents = getRecentStations();

    // Eliminar si ya existía para ponerla al inicio
    recents.removeWhere((s) => s.stationUuid == station.stationUuid);
    recents.insert(0, station);

    // Mantener un máximo de 15 emisoras en el historial
    if (recents.length > 15) {
      recents.removeLast();
    }

    await _prefs?.setStringList(
      _keyRecents,
      recents.map((s) => json.encode(s.toJson())).toList(),
    );
  }

  /// Retorna la lista de emisoras recientemente escuchadas.
  List<RadioStation> getRecentStations() {
    final jsonList = _prefs?.getStringList(_keyRecents) ?? [];
    return jsonList
        .map((str) {
          try {
            return RadioStation.fromJson(json.decode(str));
          } catch (_) {
            return null;
          }
        })
        .whereType<RadioStation>()
        .toList();
  }
}
