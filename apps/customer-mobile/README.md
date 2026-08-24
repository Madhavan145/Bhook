# Bhook Customer App

Flutter customer mobile application for the Bhook campus food platform.

## Getting started

```bash
flutter pub get
flutter run
```

## Structure

```
lib/
├─ main.dart
└─ src/
   ├─ app.dart
   ├─ features/     # feature modules (auth, campus, catalog, cart, orders)
   ├─ core/         # api client, config, theme, router
   └─ data/         # models, repositories
```

The app is Riverpod-based, uses go_router for navigation and Dio for HTTP.
