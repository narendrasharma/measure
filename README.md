# DimScan — AR Object Measurement Flutter App

A professional Flutter prototype for measuring object dimensions using your phone camera. 
Built with a dark industrial aesthetic, AR overlay simulation, and full measurement history.

---

## 📱 Screenshots Overview

| Splash | Home | AR Measure | Result | History |
|--------|------|------------|--------|---------|
| Animated logo | 3 mode cards | Camera + tap points | Result sheet | Saved list |

---

## 🚀 Quick Setup

### Prerequisites
- Flutter SDK `>=3.10.0`
- Dart `>=3.0.0`
- Android Studio / Xcode
- Physical device (recommended for AR)

### Install & Run

```bash
# 1. Navigate into project
cd measure_app

# 2. Install dependencies
flutter pub get

# 3. Run on device
flutter run

# Or build APK
flutter build apk --release
```

---

## 📂 Project Structure

```
lib/
├── main.dart                          # Entry point, routes, theme
├── models/
│   └── measurement.dart               # Measurement data model (cm/in, save/load)
├── utils/
│   ├── app_theme.dart                 # Dark industrial theme, colors, fonts
│   └── measurement_storage.dart       # SharedPreferences persistence
├── screens/
│   ├── splash_screen.dart             # Animated splash with scan grid
│   ├── home_screen.dart               # Mode selection + recent measurements
│   ├── measure_screen.dart            # Camera + AR overlay + tap-to-measure
│   └── history_screen.dart            # Saved measurements, swipe-to-delete
└── widgets/
    ├── scan_overlay.dart              # AR corner brackets + surface detection UI
    ├── crosshair_widget.dart          # Animated Point A/B indicators
    └── measurement_result_sheet.dart  # Result bottom sheet with unit conversions
```

---

## 🔧 Adding Real AR (Production Steps)

The prototype uses a simulated camera background with AR-style UI. To add real measurement:

### Step 1 — Real Camera Feed
Replace `_buildCameraBackground()` in `measure_screen.dart`:

```dart
// Add to pubspec: camera: ^0.10.5+9
import 'package:camera/camera.dart';

CameraController _cameraController;

// In initState:
final cameras = await availableCameras();
_cameraController = CameraController(cameras[0], ResolutionPreset.high);
await _cameraController.initialize();

// In build:
CameraPreview(_cameraController)  // replaces _buildCameraBackground()
```

### Step 2 — AR Hit Testing (ARCore/ARKit)
```dart
// pubspec: ar_flutter_plugin_flutterflow: ^0.0.9
import 'package:ar_flutter_plugin_flutterflow/ar_flutter_plugin.dart';

ARView(
  onARViewCreated: (arSessionManager, arObjectManager, arAnchorManager, arLocationManager) {
    _arSessionManager = arSessionManager;
    _arSessionManager!.onInitialize(
      showFeaturePoints: true,
      showPlanes: true,
      customPlaneTexturePath: "assets/triangle.png",
      showWorldOrigin: false,
    );
  },
)

// On tap → do hit test:
final hitTestResults = await _arSessionManager!.onPlaneOrPointTap(event);
if (hitTestResults.isNotEmpty) {
  final worldPos = hitTestResults.first.worldTransform;
  // Store worldPos as Point A or B
  // Calculate distance using vector_math
}
```

### Step 3 — Real Distance Calculation
```dart
import 'package:vector_math/vector_math_64.dart';

double getRealWorldDistance(Matrix4 transformA, Matrix4 transformB) {
  final posA = Vector3(transformA[12], transformA[13], transformA[14]);
  final posB = Vector3(transformB[12], transformB[13], transformB[14]);
  return (posA - posB).length * 100; // convert meters → cm
}
```

---

## 🎯 Features

### ✅ Implemented (Prototype)
- [x] 3 measurement modes: AR, Reference Object, Height Sensor
- [x] Animated splash screen with scan grid
- [x] Dark industrial UI with cyan accent
- [x] AR-style scan overlay with corner brackets + surface detection
- [x] Tap Point A / Point B measurement flow
- [x] Animated crosshair widgets
- [x] Result bottom sheet with unit conversions (mm, cm, in, ft, m)
- [x] Clipboard copy
- [x] Save measurements with custom labels
- [x] History screen with swipe-to-delete
- [x] Unit toggle (cm ↔ inches) in HUD
- [x] Camera permission handling
- [x] Android & iOS manifests with correct permissions
- [x] Simulated AR plane detection flow

### 🔲 Next Steps for Production
- [ ] Real camera feed via `camera` package
- [ ] Real AR hit testing via `ar_flutter_plugin`
- [ ] Accelerometer-based height calculation (for Height Sensor mode)
- [ ] Reference object scale calibration (coin/card detection via ML Kit)
- [ ] Screenshot capture of measurement
- [ ] Export to PDF / share
- [ ] Multi-point measurement (perimeter, area)
- [ ] Flashlight toggle

---

## 📦 Dependencies

| Package | Purpose |
|---------|---------|
| `camera` | Live camera feed |
| `ar_flutter_plugin_flutterflow` | AR Core/Kit integration |
| `permission_handler` | Runtime permissions |
| `google_fonts` | Space Grotesk + Orbitron fonts |
| `flutter_animate` | Smooth UI animations |
| `shared_preferences` | Local measurement storage |
| `vector_math` | 3D distance calculation |

---

## 📐 Accuracy Notes

| Method | Expected Accuracy | Device Requirement |
|--------|------------------|--------------------|
| ARCore (Android) | ±5–15mm | ARCore-compatible device |
| ARKit (iPhone) | ±3–8mm | iPhone 6s+ |
| LiDAR (iPhone Pro) | ±1–3mm | iPhone 12 Pro+ |
| Reference Object | ±5–20mm (depends on calibration) | Any camera |
| Height Sensor | ±2–5cm | Accelerometer required |

---

## 🎨 Design

- **Theme**: Dark industrial / precision instrument
- **Primary font**: Space Grotesk (UI), Orbitron (numbers/readouts)
- **Accent color**: `#00E5FF` cyan
- **Background**: `#0A0C0F` near-black

---

*Built as a client prototype — ready to integrate real AR in production.*
