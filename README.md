# Plant Scan

A Flutter app that identifies a plant from a photo, reports what it can see about
the plant's condition, and keeps the ones you save with their care notes.

## Running it

The project is generated as `lib/`, `test/`, and `pubspec.yaml` only, so drop it
into a fresh Flutter app shell to get the native folders:

```bash
flutter create --org com.example --project-name plant_scan plant_scan_app
cp -R plant_scan/lib plant_scan/test plant_scan/pubspec.yaml \
      plant_scan/analysis_options.yaml plant_scan_app/
cd plant_scan_app
flutter pub get
flutter run
```

With no configuration it runs on canned sample results, so every screen is
clickable before you wire up a backend. The home screen says so while that is
the case.

## Wiring up identification

`PlantIdentifier` is a one-method interface, and `identifier_config.dart` picks
an implementation from compile-time values. Two options:

```bash
# Development: talk to the API directly.
flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...

# Production: point at your own server, which holds the key.
flutter run --dart-define=IDENTIFY_PROXY_URL=https://api.example.com/identify
```

Use the proxy for anything you ship. A key compiled into an app binary can be
pulled out of it by anyone who downloads the app, and it carries your billing.
The proxy needs to accept the same JSON body the app sends, add the
`x-api-key` and `anthropic-version` headers, forward it to
`https://api.anthropic.com/v1/messages`, and return the response untouched —
about fifteen lines in any framework. Rate limit it per device while you're
there.

To use a dedicated plant API instead (Plant.id, PlantNet) or an on-device
TFLite classifier, write another `implements PlantIdentifier` class and return
it from `_build()`. Nothing in the UI touches the network.

## Native setup

**iOS** — add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Plant Scan uses the camera to photograph plants for identification.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Plant Scan reads photos you choose so it can identify the plant in them.</string>
```

**Android** — the `camera` plugin needs `minSdk 21`; check
`android/app/build.gradle`. The plugin's own manifest declares the camera
permission, so you don't need to add one, and `image_picker` needs nothing on
modern Android.

Both plugins prompt on first use. If the person declines, the camera screen
explains why the preview is blank and offers the photo library instead.

## How it fits together

```
lib/
├── main.dart                  camera discovery, repository warm-up
├── app.dart                   Identify / My plants shell
├── theme.dart                 palette and type scale
├── models/
│   ├── plant_identification.dart   result + tolerant JSON parsing
│   └── scan_record.dart            a saved photo and its result
├── services/
│   ├── plant_identifier.dart       interface, errors, the prompt contract
│   ├── claude_plant_identifier.dart vision backend
│   ├── sample_plant_identifier.dart offline canned results
│   ├── identifier_config.dart      build-time wiring
│   ├── photo_source.dart           library picker, downscaled
│   └── scan_repository.dart        JSON index + photo files on disk
├── screens/                   home, camera, result, log
└── widgets/                   care grid, health badge, confidence meter
```

State is a `ChangeNotifier` singleton read through `ListenableBuilder`, and
storage is a JSON index plus JPEG files in the documents directory. Neither
needs a package, and both are easy to replace with Riverpod and sqflite if the
app grows past a few hundred scans.

Photos are captured at 720p and library picks are downscaled to 1500px. Larger
images cost upload time without improving identification.

## Tests

```bash
flutter test
```

Covers the JSON parser against malformed and partial replies, and the network
layer against fenced JSON, rejected keys, and unreadable responses.

## Things to know

Results come from a general vision model, not a botanical database. It reads
confidence honestly enough to be useful as a sort key, but a low score with
named alternates is the interesting case — that's why the result screen shows
both rather than a bare percentage. The app never presents a plant as safe to
eat, and the prompt refuses foraging and medicinal advice.
