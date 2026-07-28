# Radio World - Aplicación Móvil de Radio Streaming (Flutter & Dart)

Aplicación móvil para Android desarrollada en **Flutter (Dart)** que permite explorar, sintonizar y escuchar miles de estaciones de radio en vivo de todo el mundo, organizadas por países, géneros y calidad de transmisión.

---

## 🌟 Características Principales

1. **Catálogo Mundial de Emisoras Organizadas por Países**:
   - Acceso a más de **5,000 estaciones de radio en vivo** alimentadas por la API gratuita de Radio Browser.
   - Sección prioritaria para **México 🇲🇽** con cobertura en todas sus ciudades y estados (CDMX, Guadalajara, Monterrey, Puebla, Tijuana, Mérida, Veracruz, etc.).
   - Visualización de banderas nacionales, tags de géneros musicales y bitrate de transmisión.

2. **Categorías y Filtros Rápidos**:
   - Filtro por géneros musicales populares: *Pop, Rock, Noticias, Salsa, Reggaeton, Jazz, Deportes*.
   - Filtro de **Calidad HD (≥128k)** para listar solo transmisiones de alta fidelidad de sonido.
   - Buscador en tiempo real por país, nombre de estación o género.

3. **Sistema de Estaciones Favoritas (❤️)**:
   - Guarda tus emisoras preferidas tocando el ícono de corazón.
   - Almacenamiento local persistente (`shared_preferences`), conservando tus favoritas incluso al cerrar la app.
   - Acceso inmediato desde la pestaña **`❤️ Favoritas`**.

4. **Historial de Escuchadas Recientemente (🕐)**:
   - Registro automático de las últimas radios que has sintonizado.
   - Acceso directo desde la pestaña **`🕐 Recientes`** para volver a sintonizar con un solo toque.

5. **Temporizador de Apagado Automático (Sleep Timer ⏱️)**:
   - Programa la desactivación automática del audio en 15, 30, 45, 60 o 90 minutos.
   - Muestra un conteo regresivo dinámico en formato `⏱️ MM:SS` tanto en la barra superior como en el reproductor.
   - Detiene la transmisión en segundo plano de forma segura sin cerrar la app.

6. **Reproducción en Segundo Plano y Notificaciones en Android (`just_audio` + `audio_service`)**:
   - Reproducción continua e ininterrumpida con la pantalla apagada o con la aplicación minimizada.
   - Integración nativa con `AudioServiceActivity` y barra de notificaciones multimedia de Android con botones de control Play/Pause/Stop.
   - Manejo transparente de protocolos HTTP y HTTPS (`usesCleartextTraffic`).

7. **Diseño UI/UX Premium (Dark Glassmorphic)**:
   - Tema oscuro nativo con acentos verde neón (`#00FF88`) y azul cian (`#38BDF8`).
   - Indicador visual animado de ecualizador en vivo para la estación activa.
   - Reproductor flotante inferior ergónomico.

---

## 📁 Estructura del Proyecto

```
App Radio/
├── pubspec.yaml                          # Configuración de dependencias y recursos
├── README.md                             # Documentación del proyecto
├── android/
│   └── app/
│       ├── build.gradle.kts              # Configuración de Gradle y NDK (27.0.12077973)
│       └── src/
│           └── main/
│               ├── AndroidManifest.xml   # Permisos de red, Foreground Service y Notificaciones
│               └── kotlin/com/example/app_radio/
│                   └── MainActivity.kt   # Herencia de AudioServiceActivity para servicios de audio
└── lib/
    ├── main.dart                         # Punto de entrada de la app y tema oscuro
    ├── models/
    │   └── radio_station.dart            # Modelo de estación con cálculo de distancias
    ├── services/
    │   ├── radio_api_service.dart        # Cliente API de Radio Browser con gestión de espejos
    │   ├── radio_audio_handler.dart      # Servicio de audio en segundo plano y Sleep Timer
    │   └── favorites_service.dart        # Persistencia de Favoritas y Recientes
    ├── screens/
    │   └── home_screen.dart              # Pantalla principal con lista por países y filtros
    └── widgets/
        └── floating_player.dart          # Reproductor flotante inferior con controles en vivo
```

---

## 🚀 Guía de Instalación y Compilación

### 1. Descargar dependencias del proyecto
```bash
flutter pub get
```

### 2. Ejecutar en Emulador o Dispositivo Android
```bash
flutter run
```

### 3. Generar el APK de Release (Producción)
Para generar el instalable Android (`app-release.apk`):
```bash
flutter build apk --release
```

El archivo APK generado estará disponible en:
```
build/app/outputs/flutter-apk/app-release.apk
```
