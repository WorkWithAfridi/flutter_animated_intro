# Bloom intro flow playground

A responsive plant-store demo using the package via `path: ../`.

```powershell
flutter pub get
flutter run -d chrome
# flutter run -d windows
```

The tour autoplays on first screen opening, adds a plant to the real local bag,
follows the bag into a bottom sheet, and highlights a supplied collection widget.
No APIs, checkout, or payments are involved. Bag contents stay after the tour.

Skip or complete the tour to access the settings panel. Try frequency policies,
screen reopening, manual replay, history reset, custom cards, dark appearance,
accent colors, and arrows. Pause is available in the custom card; Resume appears
in the controller panel. Durable history uses app-owned SharedPreferences.

`main.dart` demonstrates all three target APIs and global modal placement.
`preferences_history_store.dart` demonstrates pluggable offline storage.

```powershell
flutter analyze
flutter test
flutter build web
```

See the [package guide](../README.md) for API contracts and integration details.
