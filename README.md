# Rumblr

Internal playground for the Rumblr fight community experience.

## Tooling

| Command | Description |
| --- | --- |
| `./scripts/check.sh` | Runs `flutter analyze` followed by `flutter test`. Fails fast on lint or unit test regressions. |
| `flutter run -d macos` | Launch the macOS build (after the first pod install, subsequent builds are much faster). |
| `flutter run -d 'iPhone 16 Plus'` | Launch the iOS simulator build. |

## Firestore seed data

Use the admin seeder to refresh sample fighters/events/highlights. Requires Firebase credentials (env vars) and a logged-in Firebase CLI session.

```bash
# install deps first
flutter pub get

# dry run (prints docs, does not write)
FIREBASE_PROJECT_ID=rumblr-f8c63 flutter pub run scripts/seed_firestore.dart --dry-run

# real writes (set the API key/app id/messaging sender id for your project)
FIREBASE_PROJECT_ID=rumblr-f8c63 \
FIREBASE_API_KEY=xxx \
FIREBASE_APP_ID=xxx \
FIREBASE_MESSAGING_SENDER_ID=xxx \
  flutter pub run scripts/seed_firestore.dart
```

The script is idempotent: existing docs are updated via `merge` and new ones are added as needed.

## Contributing

1. Pull the latest main branch.
2. Run `flutter pub get` to install dependencies.
3. Make your changes.
4. Run `./scripts/check.sh` before submitting.
# Rumblr_
