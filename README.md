# ZENQIVO Player

ZENQIVO Player is a premium black/gold Flutter media-player project for mobile and Android TV. It includes device activation, profiles, Live TV, Movies, Series, XMLTV EPG, M3U, Xtream-compatible sources, favorites, continue watching, parental controls, Arabic/English UI, and a Node.js management backend.

ZENQIVO Player does not provide channels, movies, subscriptions, or bundled media. Users are responsible for connecting only sources they are authorized to use.

## Current version

- App: `0.14.0+14`
- Backend: `0.14.0`
- Android package: `com.zenqivo.player`

## Main features

- Persistent Device ID + Device Key
- Device activation lifecycle with expiry
- M3U playlist parsing
- Xtream-compatible Live / Movies / Series
- Seasons and episodes
- XMLTV EPG
- Premium Android TV layout and remote navigation
- media_kit playback engine
- Audio track selection
- Subtitle track selection and external subtitle URL
- Playback speed and aspect ratio controls
- Fast Live TV channel switching
- Favorites
- Recently watched
- Continue watching
- Multiple local profiles
- Profile-scoped history/favorites/progress
- Parental PIN
- Arabic and English UI
- Premium activation and profile screens
- Admin dashboard for devices and playlists
- AES-256-GCM encryption for provider passwords at rest
- HTTPS-only Android release configuration
- Session cache and stale-data fallback for catalog/EPG

## Requirements

### Flutter app

Use a Flutter SDK compatible with the SDK constraint in `pubspec.yaml`:

```yaml
sdk: '>=3.10.0 <4.0.0'
```

Android release builds require JDK 17.

### Backend

Node.js `22.5.0+` is required because the backend uses the built-in `node:sqlite` API.

## Backend setup

Create environment variables from the example:

```bash
cd backend
cp .env.example .env
```

Set strong unique values:

```env
PORT=8787
ZENQIVO_ADMIN_TOKEN=CHANGE_TO_A_LONG_RANDOM_SECRET
ZENQIVO_CREDENTIAL_KEY=CHANGE_TO_A_DIFFERENT_LONG_RANDOM_SECRET
```

The backend intentionally refuses to start if either security secret is missing or shorter than 24 characters.

Run:

```bash
ZENQIVO_ADMIN_TOKEN='your-long-admin-token' \
ZENQIVO_CREDENTIAL_KEY='your-long-encryption-secret' \
npm start
```

Health check:

```text
GET /health
```

Admin UI:

```text
https://YOUR-DOMAIN/admin
```

For production, terminate TLS at a reverse proxy or load balancer and expose the backend only through HTTPS.


## One-command QA

From the project root:

```bash
./scripts/qa.sh
```

This runs backend syntax checks and integration tests. If Flutter is installed, it also runs `flutter pub get`, `flutter analyze`, and `flutter test`.

## Backend tests

Run the built-in integration test:

```bash
cd backend
npm test
```

The test covers:

1. backend startup and health check
2. device registration
3. blocked sync before activation
4. activation
5. playlist creation
6. active-device sync
7. playlist enable/disable
8. playlist deletion
9. device deletion

## Flutter API configuration

Debug emulator default:

```text
http://10.0.2.2:8787
```

A physical Android device or Android TV can point to a LAN backend during development:

```bash
flutter run \
  --dart-define=ZENQIVO_API_URL=http://192.168.1.50:8787
```

Production release must use HTTPS:

```bash
flutter build apk --release \
  --dart-define=ZENQIVO_API_URL=https://api.your-domain.com
```

Or build an App Bundle:

```bash
flutter build appbundle --release \
  --dart-define=ZENQIVO_API_URL=https://api.your-domain.com
```


## GitHub Actions APK build

The repository includes `.github/workflows/build-apk.yml`.

After pushing the project to GitHub:

1. Open **Actions**.
2. Select **Build ZENQIVO APK**.
3. Choose **Run workflow**.
4. Enter the HTTPS backend URL if available.
5. Wait for the workflow to complete.
6. Download the `ZENQIVO-Player-APK` artifact.

The workflow currently creates an installable **debug APK** for device testing. A signed production release APK/AAB still requires the Android release keystore described below.

## Android release signing

Copy:

```text
android/key.properties.example
```

to:

```text
android/key.properties
```

Then set the path and passwords for your release keystore.

`android/key.properties`, `*.jks`, and `*.keystore` are ignored by Git and must never be committed.

## Recommended release checklist

Before shipping:

- Use a real HTTPS domain for `ZENQIVO_API_URL`.
- Generate unique production admin/encryption secrets.
- Generate and securely store the Android release keystore.
- Run `npm test` in `backend/`.
- Run `flutter pub get`.
- Run `flutter analyze`.
- Run `flutter test`.
- Test Android phone UI.
- Test Android TV with a physical remote.
- Test M3U and Xtream-compatible sources you are authorized to use.
- Test a large playlist and XMLTV EPG.
- Test activation expiry and reactivation.
- Test every profile separately.
- Test parental PIN access from Home, Search, History, Movies, Series, and Live.
- Test audio/subtitle tracks on representative streams.
- Build a signed release APK/AAB.
- Install the release build on a clean Android TV/device.

## Security notes

- Provider passwords are encrypted at rest with AES-256-GCM.
- The encryption key is supplied by `ZENQIVO_CREDENTIAL_KEY`; changing it makes existing encrypted passwords unreadable.
- Device keys are not exposed in the admin device list.
- Production Android builds disallow cleartext HTTP traffic.
- Debug Android builds allow local HTTP for development.
- Admin API calls require the `x-admin-token` header.
- Never commit `.env`, SQLite databases, release keystores, or signing passwords.

## Repository layout

```text
android/                 Android + Android TV native configuration
assets/                  ZENQIVO application assets
backend/                 Node.js + SQLite activation/admin backend
lib/core/                Models, API, localization, services, theme
lib/features/            Activation, profiles, home, live, library, player, settings
test/                    Flutter test location
```

## Important build note

The project has been structurally validated and the backend integration flow is tested. A final Flutter APK/AAB must still be built with an installed Flutter SDK before publication.
