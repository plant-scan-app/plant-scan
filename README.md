# Plant Scan

A Flutter app that identifies a plant from a photo, reports what it can see about
the plant's condition, and keeps the ones you save with their care notes.

## Running it

The project is generated as `lib/`, `test/`, and `pubspec.yaml` only, so drop it
into a fresh Flutter app shell to get the native folders:

```bash
flutter create --org com.example --project-name plant_scan plant_scan_app

# Copy the *contents* of each folder. The trailing /. matters — without it
# you get plant_scan_app/lib/lib and the template main.dart survives.
cp -R plant_scan/lib/.  plant_scan_app/lib/
cp -R plant_scan/test/. plant_scan_app/test/
cp plant_scan/pubspec.yaml plant_scan/analysis_options.yaml plant_scan_app/

# The generated test targets the counter app and will fail.
rm -f plant_scan_app/test/widget_test.dart

cd plant_scan_app
flutter pub get
flutter run
```

On Windows PowerShell:

```powershell
flutter create --org com.example --project-name plant_scan plant_scan_app

Copy-Item plant_scan\lib\*  plant_scan_app\lib\  -Recurse -Force
Copy-Item plant_scan\test\* plant_scan_app\test\ -Recurse -Force
Copy-Item plant_scan\pubspec.yaml, plant_scan\analysis_options.yaml plant_scan_app\ -Force
Remove-Item plant_scan_app\test\widget_test.dart -ErrorAction SilentlyContinue

cd plant_scan_app
flutter pub get
flutter run
```

If the app starts on the Flutter counter demo, the copy went into a nested
`lib/lib` folder. Delete that and copy again.

Pick a phone target rather than Chrome. `path_provider` has no web
implementation, so saving a scan fails there, and the `camera` plugin's web
support is limited to a basic preview.

With no configuration it runs on canned sample results, so every screen is
clickable before you wire up a backend. The home screen says so while that is
the case.

## Wiring up identification

`PlantIdentifier` is a one-method interface, and `identifier_config.dart` picks
an implementation from compile-time values. Nothing in the UI touches the
network, so swapping backends changes one line.

Gemini has a free tier, which makes it the easy starting point. Get a key from
[aistudio.google.com/apikey](https://aistudio.google.com/apikey), then:

```bash
flutter run --dart-define=GEMINI_API_KEY=AIza...

# Claude instead:
flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...

# Either one behind your own server, which holds the key:
flutter run --dart-define=IDENTIFY_PROXY_URL=https://api.example.com/identify \
            --dart-define=IDENTIFY_PROXY_FLAVOUR=gemini

# Model names on both APIs churn. Override without touching the code:
flutter run --dart-define=GEMINI_API_KEY=AIza... \
            --dart-define=IDENTIFY_MODEL=gemini-2.5-flash
```

The key is passed at build time and never written to a file, so there is
nothing for git to pick up. It does end up inside the built binary, though,
which is why the proxy option exists — anyone who downloads a release APK can
extract a compiled-in key, and it bills to you. For a project you and a friend
run from source, a direct key is fine.

A proxy needs about fifteen lines: accept the body the app sends, add the
`x-goog-api-key` header (or `x-api-key` plus `anthropic-version` for Claude),
forward it to the provider, return the response untouched. Rate limit per
device while you're there.

Two things about the free tier. Requests are capped per minute, and the app
surfaces a 429 as "the free tier limit is reached" rather than a raw error.
Google may also use free-tier requests to improve their models, so don't point
it at anything you consider private — a photo of a houseplant is not that, but
it's worth knowing.

To use a dedicated plant API instead (Plant.id, PlantNet) or an on-device
TFLite classifier, write another `implements PlantIdentifier` class and return
it from `_build()`.

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
│   ├── backend_client.dart         talks to server/, carries quota
│   ├── entitlements.dart           quota state + backend identifier
│   ├── device_identity.dart        anonymous per-install id
│   ├── ads_service.dart            AdMob, with the policy rules documented
│   ├── subscription_service.dart   Play Billing purchases
│   ├── gemini_plant_identifier.dart Gemini direct (development)
│   ├── claude_plant_identifier.dart Claude direct (development)
│   ├── sample_plant_identifier.dart offline canned results
│   ├── identifier_config.dart      build-time wiring
│   ├── photo_source.dart           library picker, downscaled
│   └── scan_repository.dart        JSON index + photo files on disk
├── screens/                   home, camera, result, log, paywall
└── widgets/                   care grid, health badge, confidence meter
```

State is a `ChangeNotifier` singleton read through `ListenableBuilder`, and
storage is a JSON index plus JPEG files in the documents directory. Neither
needs a package, and both are easy to replace with Riverpod and sqflite if the
app grows past a few hundred scans.

Photos are captured at 720p and library picks are downscaled to 1500px. Larger
images cost upload time without improving identification.

## Free tier, ads, and subscriptions

Three free scans a day. When they run out, an opt-in rewarded ad earns two
more, once per day, so a normal day is about five scans. Above that, a
subscription removes the limit and all ads.

**Both limits are enforced on the server**, in `server/src/quota.ts`. A daily
count kept on the device is reset by clearing app data, and a subscription flag
checked in the app is bypassed by patching the APK. The client only ever
displays what the server last said.

Ad placement follows two rules from Play's ads policy, written up in
`ads_service.dart`:

- No full-screen ad blocks what the user asked for. The interstitial fires
  after a result has been read and closed, never before it appears, and only
  every third result.
- Rewarded ads are opt-in, with the reward stated before the user chooses.

An unskippable ad gating results would risk AdMob account termination, which is
generally not appealable. Don't be tempted.

Ads and billing are no-ops on web and on any build without a backend, so
`flutter run -d chrome` still works for UI iteration.

### Play Console setup

Create a subscription with two base plans, matching the IDs in
`subscription_service.dart`:

| Base plan ID | Price | Notes |
| --- | --- | --- |
| `plant_scan_monthly` | $2.99 / month | |
| `plant_scan_yearly` | $19.99 / year | Add a 7-day free trial offer |

Prices are read from the store at runtime, so they display in each user's own
currency and follow whatever you set in Play Console. Nothing is hardcoded.

### AdMob setup

Create an AdMob app and three ad units — banner, interstitial, rewarded. The
app ID goes in `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"/>
```

Unit IDs are passed at build time. Without them the app uses Google's public
test units, which is what you want while developing — never click your own
live ads, it gets accounts banned.

## Releasing on Android

```bash
flutter build appbundle --release \
  --dart-define=BACKEND_URL=https://plant-scan-api.YOUR-SUBDOMAIN.workers.dev \
  --dart-define=ADMOB_BANNER_ID=ca-app-pub-.../... \
  --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-.../... \
  --dart-define=ADMOB_REWARDED_ID=ca-app-pub-.../...
```

Never pass `GEMINI_API_KEY` to a release build. Use `BACKEND_URL`.

Before the first upload:

- Set `applicationId` in `android/app/build.gradle.kts` to something you own,
  e.g. `com.ongama.plantscan`. It can never be changed after publishing.
- Set the app label in `AndroidManifest.xml`.
- Generate a signing keystore, keep it and `android/key.properties` out of git,
  and back the keystore up somewhere safe — losing it means you cannot update
  the listing.
- Add the AdMob app ID meta-data shown above.

Two Play Console realities: new personal developer accounts must run a closed
test with 12 testers for 14 days before production access, and the Data safety
form must declare that photos are sent off the device for identification. You
will also need a privacy policy URL.

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
