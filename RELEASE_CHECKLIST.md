# ZENQIVO Release Checklist

## Required before the first public release

- [ ] Install a Flutter SDK compatible with `pubspec.yaml`.
- [ ] Run `./scripts/qa.sh`.
- [ ] Run `flutter analyze` with zero blocking errors.
- [ ] Run `flutter test`.
- [ ] Configure a production HTTPS API domain.
- [ ] Set `ZENQIVO_ADMIN_TOKEN` to a unique secret of at least 24 characters.
- [ ] Set `ZENQIVO_CREDENTIAL_KEY` to a different unique secret of at least 24 characters.
- [ ] Back up `ZENQIVO_CREDENTIAL_KEY`; losing it makes stored provider passwords unreadable.
- [ ] Create the Android release keystore.
- [ ] Create `android/key.properties` from the provided example.
- [ ] Keep the keystore and passwords outside Git.
- [ ] Build a signed release APK.
- [ ] Build a signed AAB if publishing through a store.
- [ ] Install the release APK on a clean Android phone.
- [ ] Install the release APK on a real Android TV / Google TV device.
- [ ] Verify D-pad focus, Back, OK/Enter, channel switching, and playback controls.
- [ ] Verify Arabic RTL and English LTR.
- [ ] Verify activation, expiry, deactivation, and reactivation.
- [ ] Verify multiple profiles and isolated history/favorites.
- [ ] Verify parental PIN from every content entry point.
- [ ] Verify authorized M3U and Xtream-compatible test sources.
- [ ] Verify XMLTV EPG.
- [ ] Verify large-catalog performance.
- [ ] Verify audio and subtitle selection.
- [ ] Verify network-loss and provider-failure behavior.
- [ ] Verify admin device and playlist management.
- [ ] Verify production backup/restore of the SQLite database.
- [ ] Confirm no `.env`, SQLite database, keystore, signing password, or production secret is committed.

## Recommended release commands

```bash
./scripts/qa.sh

flutter build apk --release \
  --dart-define=ZENQIVO_API_URL=https://api.your-domain.com

flutter build appbundle --release \
  --dart-define=ZENQIVO_API_URL=https://api.your-domain.com
```

A release build intentionally fails if `android/key.properties` is missing.
