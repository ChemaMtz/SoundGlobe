import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/radio_station.dart';

/// Servicio que consume Radio Browser API (api.radio-browser.info).
/// La API TIENE coordenadas reales: 954/1000 estaciones de México tienen geo_lat/geo_long.
/// Simplemente hay que pedirlas correctamente y no filtrarlas con condiciones erróneas.
class RadioApiService {
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

  /// Descarga en caché:
  /// 1. Todas las emisoras de México con coordenadas reales (~954 estaciones)
  /// 2. Top 5000 más escuchadas del mundo con coordenadas reales (~1159 estaciones)
  Future<List<RadioStation>> getTopGlobalStations({int limit = 5000}) async {
    for (int attempt = 0; attempt < _mirrors.length; attempt++) {
      try {
        _cachedGeoStations.clear();
        _cachedUuids.clear();

        // ─── 1. Todas las emisoras de México ───────────────────────────────
        final mxUri = Uri.parse(
          '$_currentBaseUrl/json/stations/bycountry/mexico?hidebroken=true',
        );
        final mxResp = await http
            .get(mxUri, headers: _headers)
            .timeout(const Duration(seconds: 12));

        if (mxResp.statusCode == 200) {
          final mxList = json.decode(mxResp.body) as List<dynamic>;
          _ingestJson(mxList);
          debugPrint('API: México → ${mxList.length} emisoras, ${_cachedGeoStations.length} con geo válida');
        }

        // ─── 2. Top mundial más escuchadas ──────────────────────────────────
        final topUri = Uri.parse(
          '$_currentBaseUrl/json/stations/topclick?limit=$limit&hidebroken=true',
        );
        final topResp = await http
            .get(topUri, headers: _headers)
            .timeout(const Duration(seconds: 15));

        if (topResp.statusCode == 200) {
          final topList = json.decode(topResp.body) as List<dynamic>;
          _ingestJson(topList);
          debugPrint('API: Top mundial → ${topList.length} emisoras, total caché: ${_cachedGeoStations.length}');
        }

        if (_cachedGeoStations.isNotEmpty) {
          return _cachedGeoStations;
        }
      } catch (e) {
        debugPrint('API Error (intento ${attempt + 1}) [$_currentBaseUrl]: $e');
        _rotateMirror();
      }
    }
    return _cachedGeoStations;
  }

  /// Parsea y añade al caché solo las estaciones con geo_lat y geo_long REALES no-cero.
  /// No inventa coordenadas: usa únicamente las que la API de Radio Browser provee.
  void _ingestJson(List<dynamic> list) {
    for (final item in list) {
      try {
        // Parsear lat/lng directamente del JSON sin pasar por el modelo para validar antes
        final rawLat = item['geo_lat'];
        final rawLng = item['geo_long'];

        if (rawLat == null || rawLng == null) continue;

        final lat = double.tryParse(rawLat.toString());
        final lng = double.tryParse(rawLng.toString());

        // Coordenada inválida o exactamente en el ecuador/meridiano (0,0) → omitir
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
