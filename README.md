# Lazulite

The Zentra mobile app, built with Flutter. It is a chat client for the Zentra
backend, sharing the same REST and websocket APIs as the web client.

## Getting started

```bash
flutter pub get
flutter run
```

The backend instance is configurable. By default it points at
`http://localhost:8080`. 

Override it with a build define:

```bash
flutter run --dart-define=ZENTRA_INSTANCE_URL=https://your-instance
flutter run --dart-define=ZENTRA_INSTANCE_NAME="Zentra Prod"
```
