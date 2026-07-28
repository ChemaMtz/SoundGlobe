import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/radio_station.dart';

/// Controlador del Globo 3D.
/// Implementa un patrón "buffer y despacho": si populateGlobalStations se llama
/// antes de que Globe.gl esté listo, guarda los datos y los envía en cuanto
/// el JS emite el evento 'globe_ready'.
class GlobeController {
  WebViewController? _webViewController;
  bool _isGlobeReady = false;
  List<RadioStation>? _pendingStations;

  void _attach(WebViewController controller) {
    _webViewController = controller;
  }

  /// Llamado por GlobeWebView cuando JS emite 'globe_ready'.
  void _onGlobeReady() {
    _isGlobeReady = true;
    debugPrint('GlobeController: Globe.gl listo ✅');
    if (_pendingStations != null) {
      debugPrint('GlobeController: Enviando ${_pendingStations!.length} estaciones pendientes.');
      _sendStationsToJS(_pendingStations!);
      _pendingStations = null;
    }
  }

  /// Pinta un anillo pulsante en la estación activa.
  void updateActiveStation(RadioStation station) {
    if (_webViewController == null || !station.hasCoordinates) return;
    final lat = station.geoLat!;
    final lng = station.geoLong!;
    final name = jsonEncode(station.name);
    final country = jsonEncode(station.country);
    _webViewController!.runJavaScript(
      'if (window.updateActiveStation) window.updateActiveStation($lat, $lng, $name, $country);',
    );
  }

  /// Envía la lista de estaciones al Globo 3D.
  /// Si Globe.gl aún no está listo, guarda los datos para enviarlos cuando esté.
  void populateGlobalStations(List<RadioStation> stations) {
    if (stations.isEmpty) return;
    if (!_isGlobeReady || _webViewController == null) {
      debugPrint('GlobeController: Globe no listo, guardando ${stations.length} estaciones en buffer.');
      _pendingStations = stations;
      return;
    }
    _sendStationsToJS(stations);
  }

  /// Método interno: serializa el array a JSON y lo asigna directamente como variable JS.
  /// Se usan DOS runJavaScript separados para evitar cualquier problema de escaping de strings.
  void _sendStationsToJS(List<RadioStation> stations) {
    final list = stations
        .where((s) => s.hasCoordinates)
        .map((s) => {
              'geo_lat': s.geoLat,
              'geo_long': s.geoLong,
              'stationuuid': s.stationUuid,
              'name': s.name,
            })
        .toList();

    if (list.isEmpty) {
      debugPrint('GlobeController: Lista filtrada vacía, nada que enviar.');
      return;
    }

    final jsonStr = jsonEncode(list);
    debugPrint('GlobeController: Enviando ${list.length} puntos al Globe 3D.');

    // Paso 1: asignar el array JS directamente como variable global (sin doble-encoding)
    _webViewController!.runJavaScript('window.__stationsData = $jsonStr;');

    // Paso 2: llamar a la función JS que lee esa variable y pinta los puntos
    _webViewController!.runJavaScript(
        'if (window.loadStationsFromGlobal) window.loadStationsFromGlobal();');
  }
}

/// Widget que renderiza el Globo 3D a pantalla completa.
class GlobeWebView extends StatefulWidget {
  final void Function(double lat, double lng) onCoordinatesSelected;
  final void Function()? onWebViewReady;
  final GlobeController? controller;

  const GlobeWebView({
    super.key,
    required this.onCoordinatesSelected,
    this.onWebViewReady,
    this.controller,
  });

  @override
  State<GlobeWebView> createState() => _GlobeWebViewState();
}

class _GlobeWebViewState extends State<GlobeWebView> {
  late final WebViewController _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF030712))
      ..setOnConsoleMessage((message) {
        debugPrint('GlobeJS [${message.level.name}]: ${message.message}');
      })
      ..addJavaScriptChannel(
        'GlobeChannel',
        onMessageReceived: _handleGlobeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (mounted) {
              setState(() => _isLoading = false);
              // onWebViewReady indica que el HTML cargó, pero Globe.gl puede seguir cargando
              widget.onWebViewReady?.call();
            }
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadFlutterAsset('assets/globe/index.html');

    widget.controller?._attach(_webViewController);
  }

  void _handleGlobeMessage(JavaScriptMessage message) {
    try {
      final Map<String, dynamic> payload = json.decode(message.message);
      final type = payload['type'] as String?;

      if (type == 'globe_ready') {
        // Globe.gl terminó de inicializarse: avisar al controlador para despachar datos pendientes
        widget.controller?._onGlobeReady();
      } else if (type == 'select_coords') {
        final lat = double.tryParse(payload['lat'].toString());
        final lng = double.tryParse(payload['lng'].toString());
        if (lat != null && lng != null) {
          widget.onCoordinatesSelected(lat, lng);
        }
      }
    } catch (e) {
      debugPrint('Error decodificando mensaje de GlobeChannel: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),
        if (_isLoading)
          Container(
            color: const Color(0xFF030712),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF88)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'INICIANDO GLOBO 3D...',
                    style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
