import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'services/radio_audio_handler.dart';

/// Punto de entrada de la aplicación móvil de Radio Garden en 3D.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar la orientación a solo vertical para una experiencia móvil consistente
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configurar la barra de estado transparente en Android
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF030712),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Inicializar el servicio de audio en segundo plano (audio_service)
  final audioHandler = await AudioService.init<RadioAudioHandler>(
    builder: () => RadioAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.app_radio.channel.audio',
      androidNotificationChannelName: 'Radio Garden Streaming en vivo',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      notificationColor: Color(0xFF00FF88),
    ),
  );

  runApp(AppRadioGarden(audioHandler: audioHandler));
}

class AppRadioGarden extends StatelessWidget {
  final RadioAudioHandler audioHandler;

  const AppRadioGarden({
    super.key,
    required this.audioHandler,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Garden 3D',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF030712),
        primaryColor: const Color(0xFF00FF88),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF88),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF0F172A),
          background: Color(0xFF030712),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: HomeScreen(audioHandler: audioHandler),
    );
  }
}
