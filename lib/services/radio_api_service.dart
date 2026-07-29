import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/radio_station.dart';

/// Servicio que consume Radio Browser API (api.radio-browser.info)
/// con sistema de Caché en Disco (SharedPreferences) para que las emisoras
/// carguen DE INMEDIATO (en 0.01s) al abrir la app sin necesidad de esperar a internet.
class RadioApiService {
  static const String _diskCacheKey = 'radio_stations_disk_cache_v2';

  static const List<String> _mirrors = [
    'https://de1.api.radio-browser.info',
    'https://at1.api.radio-browser.info',
    'https://nl1.api.radio-browser.info',
    'https://fr1.api.radio-browser.info',
  ];

  String _currentBaseUrl = _mirrors.first;

  final List<RadioStation> _cachedGeoStations = [];
  final Set<String> _cachedUuids = {};

  Map<String, String> get _headers => {
        'User-Agent': 'AppRadioGardenClone/1.0 (Flutter Mobile App)',
        'Accept': 'application/json',
      };

  /// Retorna las emisoras más cercanas a (lat, lng) usando Haversine sobre el caché.
  Future<List<RadioStation>> getStationsNearCoords(
    double lat,
    double lng, {
    int limit = 25,
  }) async {
    if (_cachedGeoStations.isEmpty) {
      await getTopGlobalStations();
    }
    if (_cachedGeoStations.isEmpty) return [];

    final sorted = List<RadioStation>.from(_cachedGeoStations);
    sorted.sort((a, b) =>
        a.distanceTo(lat, lng).compareTo(b.distanceTo(lat, lng)));
    return sorted.take(limit).toList();
  }

  /// Retorna las emisoras almacenadas.
  /// 1. Si ya están cargadas en memoria, las retorna inmediatamente.
  /// 2. Si hay caché guardado en el disco local, las carga de inmediato sin hacer peticiones a internet.
  /// 3. Si no hay nada guardado en disco (o forceRefresh == true), descarga de la API y las guarda en el disco local.
  Future<List<RadioStation>> getTopGlobalStations({
    int limit = 5000,
    bool forceRefresh = false,
  }) async {
    // Si ya tenemos estaciones en memoria y no es recarga forzada, retornar directamente
    if (_cachedGeoStations.isNotEmpty && !forceRefresh) {
      return _cachedGeoStations;
    }

    // Intentar cargar primero del almacenamiento local del teléfono (disco)
    if (!forceRefresh) {
      final diskStations = await _loadFromDiskCache();
      if (diskStations.isNotEmpty) {
        _cachedGeoStations.clear();
        _cachedUuids.clear();
        for (final s in diskStations) {
          _cachedUuids.add(s.stationUuid);
          _cachedGeoStations.add(s);
        }
        debugPrint('RadioApiService: Cargadas ${diskStations.length} emisoras desde Caché Local (instantáneo).');
        return _cachedGeoStations;
      }
    }

    // Si el caché local estaba vacío o se solicitó recargar (forceRefresh == true), consultar la API de red
    for (int attempt = 0; attempt < _mirrors.length; attempt++) {
      try {
        _cachedGeoStations.clear();
        _cachedUuids.clear();

        // 1. Emisoras de México
        final mxUri = Uri.parse(
          '$_currentBaseUrl/json/stations/bycountry/mexico?hidebroken=true',
        );
        final mxResp = await http
            .get(mxUri, headers: _headers)
            .timeout(const Duration(seconds: 12));

        if (mxResp.statusCode == 200) {
          final mxList = json.decode(mxResp.body) as List<dynamic>;
          _ingestJson(mxList);
        }

        // 2. Top mundial más escuchadas
        final topUri = Uri.parse(
          '$_currentBaseUrl/json/stations/topclick?limit=$limit&hidebroken=true',
        );
        final topResp = await http
            .get(topUri, headers: _headers)
            .timeout(const Duration(seconds: 15));

        if (topResp.statusCode == 200) {
          final topList = json.decode(topResp.body) as List<dynamic>;
          _ingestJson(topList);
        }

        if (_cachedGeoStations.isNotEmpty) {
          debugPrint('RadioApiService: Descargadas de la API y guardando en disco ${_cachedGeoStations.length} emisoras.');
          // Guardar copia de respaldo en el disco local del teléfono
          await _saveToDiskCache(_cachedGeoStations);
          return _cachedGeoStations;
        }
      } catch (e) {
        debugPrint('API Error (intento ${attempt + 1}) [$_currentBaseUrl]: $e');
        _rotateMirror();
      }
    }
    return _cachedGeoStations;
  }

  /// Guarda la lista completa de estaciones en el almacenamiento interno del teléfono.
  Future<void> _saveToDiskCache(List<RadioStation> stations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = stations.map((s) => json.encode(s.toJson())).toList();
      await prefs.setStringList(_diskCacheKey, jsonList);
    } catch (e) {
      debugPrint('Error guardando en caché local: $e');
    }
  }

  /// Carga la lista de estaciones desde el almacenamiento interno del teléfono.
  Future<List<RadioStation>> _loadFromDiskCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_diskCacheKey);
      if (jsonList == null || jsonList.isEmpty) return [];

      final list = <RadioStation>[];
      for (final str in jsonList) {
        try {
          final map = json.decode(str) as Map<String, dynamic>;
          list.add(RadioStation.fromJson(map));
        } catch (_) {}
      }
      return list;
    } catch (e) {
      debugPrint('Error leyendo del caché local: $e');
      return [];
    }
  }

  /// Parsea y añade al caché solo las estaciones con geo_lat y geo_long REALES no-cero.
  void _ingestJson(List<dynamic> list) {
    for (final item in list) {
      try {
        final rawLat = item['geo_lat'];
        final rawLng = item['geo_long'];

        if (rawLat == null || rawLng == null) continue;

        final lat = double.tryParse(rawLat.toString());
        final lng = double.tryParse(rawLng.toString());

        if (lat == null || lng == null) continue;
        if (lat == 0.0 && lng == 0.0) continue;
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;

        final uuid = item['stationuuid']?.toString() ?? '';
        if (uuid.isEmpty || _cachedUuids.contains(uuid)) continue;

        final url = (item['url_resolved']?.toString().isNotEmpty == true)
            ? item['url_resolved'].toString()
            : (item['url']?.toString() ?? '');
        if (url.isEmpty) continue;

        _cachedUuids.add(uuid);
        _cachedGeoStations.add(RadioStation(
          stationUuid: uuid,
          name: item['name']?.toString().trim().isNotEmpty == true
              ? item['name'].toString().trim()
              : 'Estación Desconocida',
          urlResolved: url,
          favicon: item['favicon']?.toString() ?? '',
          country: item['country']?.toString() ?? '',
          state: item['state']?.toString() ?? '',
          tags: item['tags']?.toString() ?? '',
          geoLat: lat,
          geoLong: lng,
          bitrate: int.tryParse(item['bitrate']?.toString() ?? '0') ?? 0,
          votes: int.tryParse(item['votes']?.toString() ?? '0') ?? 0,
        ));
      } catch (e) {
        continue;
      }
    }
  }

  /// Búsqueda por nombre.
  Future<List<RadioStation>> searchStationsByName(
    String query, {
    int limit = 25,
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse(
        '$_currentBaseUrl/json/stations/byname/${Uri.encodeComponent(query)}?limit=$limit&hidebroken=true',
      );
      final resp = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final list = json.decode(resp.body) as List<dynamic>;
        return list
            .map((item) => RadioStation.fromJson(item))
            .where((s) => s.urlResolved.isNotEmpty)
            .toList();
      }
    } catch (e) {
      _rotateMirror();
    }
    return [];
  }

  List<RadioStation> get cachedStations => _cachedGeoStations;

  void _rotateMirror() {
    final i = _mirrors.indexOf(_currentBaseUrl);
    _currentBaseUrl = _mirrors[(i + 1) % _mirrors.length];
  }
}
