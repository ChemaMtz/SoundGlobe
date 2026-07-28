import 'dart:math' as math;

/// Modelo que representa una emisora de radio obtenida de la Radio Browser API.
class RadioStation {
  final String stationUuid;
  final String name;
  final String urlResolved;
  final String favicon;
  final String country;
  final String state;
  final String tags;
  final double? geoLat;
  final double? geoLong;
  final int bitrate;
  final int votes;

  const RadioStation({
    required this.stationUuid,
    required this.name,
    required this.urlResolved,
    required this.favicon,
    required this.country,
    required this.state,
    required this.tags,
    this.geoLat,
    this.geoLong,
    required this.bitrate,
    required this.votes,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    final lat = double.tryParse(json['geo_lat']?.toString() ?? '');
    final long = double.tryParse(json['geo_long']?.toString() ?? '');
    
    final url = (json['url_resolved']?.toString().isNotEmpty == true)
        ? json['url_resolved'].toString()
        : (json['url']?.toString() ?? '');

    return RadioStation(
      stationUuid: json['stationuuid']?.toString() ?? '',
      name: (json['name']?.toString().trim().isNotEmpty == true)
          ? json['name'].toString().trim()
          : 'Estación Desconocida',
      urlResolved: url,
      favicon: json['favicon']?.toString() ?? '',
      country: json['country']?.toString() ?? 'Mundo',
      state: json['state']?.toString() ?? '',
      tags: json['tags']?.toString() ?? '',
      geoLat: lat,
      geoLong: long,
      bitrate: int.tryParse(json['bitrate']?.toString() ?? '0') ?? 0,
      votes: int.tryParse(json['votes']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stationuuid': stationUuid,
      'name': name,
      'url_resolved': urlResolved,
      'favicon': favicon,
      'country': country,
      'state': state,
      'tags': tags,
      'geo_lat': geoLat,
      'geo_long': geoLong,
      'bitrate': bitrate,
      'votes': votes,
    };
  }

  /// Retorna la ubicación formateada (ej: "Madrid, España" o "España").
  String get displayLocation {
    if (state.isNotEmpty && country.isNotEmpty) {
      return '$state, $country';
    } else if (country.isNotEmpty) {
      return country;
    }
    return 'Transmisión Global';
  }

  /// Verifica si la estación tiene coordenadas geográficas válidas en el globo.
  bool get hasCoordinates => geoLat != null && geoLong != null;

  /// Retorna una lista limpia de tags/géneros musicales.
  List<String> get tagList {
    if (tags.isEmpty) return [];
    return tags
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .take(3)
        .toList();
  }

  /// Calcula la distancia en kilómetros respecto a un punto (lat, lng).
  double distanceTo(double lat, double lng) {
    if (!hasCoordinates) return double.infinity;
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat - geoLat!);
    final dLng = _degreesToRadians(lng - geoLong!);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(geoLat!)) *
            math.cos(_degreesToRadians(lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }
}
