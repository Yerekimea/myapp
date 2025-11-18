# Google Maps Migration Guide

## Summary

Your app has been successfully migrated from **Mapbox** to **Google Maps Platform**. All references to Mapbox have been replaced with Google Maps Flutter SDK equivalents.

## Changes Made

### 1. Dependencies (`pubspec.yaml`)
- **Removed:** `mapbox_maps_flutter: ^2.0.0`
- **Added:** `google_maps_flutter: ^2.5.0`

Run the following after pulling changes:
```bash
flutter pub get
```

### 2. Code Changes

#### `lib/main.dart`
- Replaced `MapboxMap?` with `GoogleMapController?`
- Replaced `MapWidget` with `GoogleMap`
- Updated marker handling from `PointAnnotationManager` to `Set<Marker>`
- Updated polyline handling from `PolylineAnnotationManager` to `Set<Polyline>`
- Updated camera animations from `mapboxMap.flyTo()` to `_mapController.animateCamera()`
- Removed map style switching (Mapbox-specific feature)

#### `lib/services/navigation_service.dart`
- Replaced Mapbox Directions API with Google Maps Directions API
- Updated `getDirectionsWithAlternatives()` to call `maps.googleapis.com/maps/api/directions/json`
- Added `NavigationRoute.fromGoogleMapsJson()` factory constructor
- Added `RouteStep.fromGoogleMapsJson()` factory constructor
- Replaced hard-coded Mapbox token with `_googleMapsApiKey` placeholder

#### Platform Configuration
- **Android:** Updated `AndroidManifest.xml` to use `com.google.android.geo.API_KEY`
- **iOS:** Updated `AppDelegate.swift` to call `GMSServices.provideAPIKey()`

#### Tests
- Updated `test/widget_test.dart` to match the navigation app structure

## ⚠️ IMPORTANT: API Key Configuration

Your app **will not work** without setting up your Google Maps API key. Follow these steps:

### Step 1: Get Your Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select an existing one
3. Enable these APIs:
   - **Maps SDK for Android**
   - **Maps SDK for iOS**
   - **Directions API**
4. Create an API key (or use an existing unrestricted key for development)
5. (Optional but recommended) Restrict your key to your Android/iOS app:
   - For Android: Add your app's SHA-1 fingerprint
   - For iOS: Add your app's bundle identifier

### Step 2: Add API Key to Android

Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_GOOGLE_MAPS_API_KEY_HERE" />
```

Replace `YOUR_ACTUAL_GOOGLE_MAPS_API_KEY_HERE` with your actual API key.

### Step 3: Add API Key to iOS

Edit `ios/Runner/AppDelegate.swift`:
```swift
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_ACTUAL_GOOGLE_MAPS_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

Replace `YOUR_ACTUAL_GOOGLE_MAPS_API_KEY_HERE` with your actual API key.

### Step 4: Add API Key to Directions Service

Edit `lib/services/navigation_service.dart`:
```dart
class NavigationService {
  static const String _googleMapsApiKey = 'YOUR_ACTUAL_GOOGLE_MAPS_API_KEY_HERE';
  // ... rest of code
}
```

Replace `YOUR_ACTUAL_GOOGLE_MAPS_API_KEY_HERE` with your actual API key.

## Testing

### Build & Run for Android
```bash
flutter run -d android
```

### Build & Run for iOS
```bash
flutter run -d ios
```

### Run Tests
```bash
flutter test
```

### Check for Errors
```bash
flutter analyze
```

## Features Supported

✅ **Map Display:**
- Interactive Google Map centered on Nigeria
- Real-time location tracking
- Multiple markers support
- Polyline route drawing

✅ **Navigation:**
- Route calculation with alternatives
- Turn-by-turn directions
- Distance and duration display
- Estimated arrival time (ETA)

✅ **Services:**
- Current speed tracking
- Weather information
- Location permissions
- Text-to-speech navigation

## Known Differences from Mapbox

1. **Map Styles:** Google Maps uses a different theming system. The app now uses the default Google Maps style instead of Mapbox's satellite/streets switching.
2. **API Response Format:** Google Maps Directions API returns data in a different format than Mapbox, handled by the new factory constructors.
3. **Polyline Encoding:** Google Maps uses polyline encoding; our implementation reconstructs coordinates from the API response.

## Removing Mapbox References

The following Mapbox token has been removed from the code:
```
pk.eyJ1IjoidG9uYnkiLCJhIjoiY21nbDVzYjdhMHhqMDJycXFxaWlkcnY2YiJ9._0ujjRjoFjGso2ZU4Zn6eQ
```

If this token was sensitive, consider rotating it in your Mapbox account.

## Troubleshooting

### "Unable to determine Google Play Services version"
- Run: `flutter clean && flutter pub get`
- Rebuild the app: `flutter run`

### API Key not working on Android
- Verify your SHA-1 fingerprint matches in Google Cloud Console
- Try removing API key restrictions for development

### Map not showing
- Ensure your API key has the Maps SDK for your platform enabled
- Check that location permissions are granted

### Directions API errors
- Verify `Directions API` is enabled in Google Cloud Console
- Check API key quotas and usage limits
- Ensure start/end coordinates are valid

## Support

For issues with Google Maps SDK:
- [Google Maps Platform Documentation](https://developers.google.com/maps/documentation)
- [google_maps_flutter Package](https://pub.dev/packages/google_maps_flutter)

For issues with your app:
- Check `flutter analyze` output
- Review logcat (Android) or Xcode console (iOS) for runtime errors
