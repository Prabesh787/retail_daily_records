# billrecord

The shop's records, on the phone. Everything is written to a local SQLite
database first and reconciled with the backend afterwards, so the app is fully
usable with no signal.

## Connecting to the backend

The server address is a compile-time constant, so it is set on the build
command and nowhere else:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
flutter build apk --dart-define=API_BASE_URL=https://shop.example.com/api/v1
```

Include the version prefix; every path the app requests is relative to it.
`10.0.2.2` is how the Android emulator reaches a server running on the host
machine — a real device needs the machine's LAN address.

Built without it, the app runs local-only: signing in says the build has no
server address, and the dashboard's sync chip reads "Local only" rather than
showing a permanent "pending". Nothing else changes, and nothing is lost —
setting the define on a later build starts syncing the records already on the
device.

Which endpoints that talks to, and how two devices' edits are merged, is in
`backend/README.md` under **Offline sync**.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
