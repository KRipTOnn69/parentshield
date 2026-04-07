# ParentShield - Smart Parental Control App

A Flutter-based parental control application that allows parents to monitor and manage their children's device usage, including app blocking, screen time limits, web filtering, and location tracking.

## Features

- **Parent Mode**: Register, login, set PIN, manage child devices
- **Child Mode**: Pair with parent via code, status monitoring
- **App Management**: Block apps, set daily time limits, schedule restrictions
- **Web Filtering**: Block categories (adult, gambling, violence, etc.) + custom URL blocklist/allowlist
- **Location Tracking**: Real-time child device location with Google Maps
- **Screen Time Reports**: Daily usage charts and statistics
- **Notifications**: Push notifications via Firebase Cloud Messaging

## Tech Stack

- **Flutter** 3.x (Dart SDK >=3.0.0)
- **Firebase**: Auth, Firestore, Cloud Messaging
- **State Management**: Provider
- **Local Storage**: Hive, SharedPreferences, FlutterSecureStorage
- **Maps**: Google Maps Flutter
- **Charts**: fl_chart

---

## Prerequisites

Before you start, install the following:

1. **Flutter SDK** (3.x or later)
   ```bash
   # macOS (Homebrew)
   brew install flutter

   # Or download from https://docs.flutter.dev/get-started/install
   ```

2. **Android Studio** or **VS Code** with Flutter/Dart plugins

3. **Java JDK 17** (for Android builds)
   ```bash
   brew install openjdk@17
   ```

4. **Xcode** (macOS only, for iOS builds)
   - Install from Mac App Store
   - Run: `sudo xcode-select --switch /Applications/Xcode.app`

5. **Firebase CLI** (optional, for deploying Firestore rules)
   ```bash
   npm install -g firebase-tools
   firebase login
   ```

---

## Setup Instructions

### Step 1: Clone the repo

```bash
git clone <repo-url>
cd parentshield
```

### Step 2: Install Flutter dependencies

```bash
flutter pub get
```

### Step 3: Firebase Configuration

This project uses Firebase project: `parentshield-1490a`

**Android** (already included):
- `android/app/google-services.json` is already in the repo
- No action needed for Android

**iOS** (required for iOS builds):
1. Go to [Firebase Console](https://console.firebase.google.com/) > Project `parentshield-1490a`
2. Click the iOS app (or add one with bundle ID: `com.example.parentshield`)
3. Download `GoogleService-Info.plist`
4. Place it in: `ios/Runner/GoogleService-Info.plist`

### Step 4: Google Maps API Key (for Location feature)

The location screen uses Google Maps. To enable it:

**Android:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Enable "Maps SDK for Android" API
3. Create an API key (or use the Firebase project's key)
4. Add it to `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_MAPS_API_KEY"/>
   ```

**iOS:**
1. Enable "Maps SDK for iOS" in Google Cloud Console
2. Add the key to `ios/Runner/AppDelegate.swift`:
   ```swift
   GMSServices.provideAPIKey("YOUR_MAPS_API_KEY")
   ```

### Step 5: Run the app

```bash
# Check everything is set up
flutter doctor

# Run on connected device or emulator
flutter run

# Run on specific device
flutter devices          # List devices
flutter run -d <device>  # Run on specific device
```

---

## Project Structure

```
lib/
  main.dart                          # App entry point, Firebase init
  config/
    constants.dart                   # App constants, colors, text styles, Firestore paths
    theme.dart                       # Light & dark theme definitions
    routes.dart                      # Named route definitions
  models/
    user_model.dart                  # Parent user model
    child_model.dart                 # Child device model + location + screen time rules
    app_rule_model.dart              # App blocking rules + web filter rules
    report_model.dart                # Daily reports, blocked attempts, location history
  services/
    auth_service.dart                # Firebase Auth + PIN hashing
    firestore_service.dart           # All Firestore CRUD operations
    location_service.dart            # GPS location tracking
    notification_service.dart        # Local + push notifications
    app_usage_service.dart           # App usage stats (Android)
    app_blocker_service.dart         # App blocking via method channel (Android)
  providers/
    auth_provider.dart               # Auth state management
    child_provider.dart              # Child device state management
  screens/
    mode_selection_screen.dart       # Parent vs Child mode picker
    parent/
      login_screen.dart              # Parent login
      register_screen.dart           # Parent registration
      pin_screen.dart                # PIN setup/verify
      dashboard_screen.dart          # Main parent dashboard (tabs)
      app_manager_screen.dart        # Manage blocked apps
      web_filter_screen.dart         # Web filter settings
      location_screen.dart           # Child location map
      reports_screen.dart            # Usage reports
      child_management_screen.dart   # Add/remove child devices
    child/
      pairing_screen.dart            # Child device pairing
      status_screen.dart             # Child status display
      blocked_overlay_screen.dart    # Blocked app overlay
  widgets/
    stat_card.dart                   # Statistics card widget
    safe_zone_card.dart              # Safe zone display card
    usage_chart.dart                 # Screen time chart
    app_tile.dart                    # App list tile
    pin_verification_dialog.dart     # PIN entry dialog
```

---

## Firebase Project Info

| Setting | Value |
|---------|-------|
| Project ID | `parentshield-1490a` |
| Project Number | `178125436872` |
| Android Package | `com.example.parentshield` |
| Storage Bucket | `parentshield-1490a.firebasestorage.app` |

### Firestore Collections

- `users/{userId}` - Parent accounts
- `users/{userId}/children/{deviceId}` - Child devices
- `users/{userId}/settings/{settingId}` - Parent settings
- `appRules/{ruleId}` - App blocking rules
- `webFilters/{filterId}` - Web filter configurations
- `reports/{reportId}` - Usage reports
- `pairingCodes/{codeId}` - Device pairing codes

---

## Build Commands

```bash
# Debug build
flutter run

# Release APK (Android)
flutter build apk --release

# Release App Bundle (Android - for Play Store)
flutter build appbundle --release

# iOS build (requires Xcode)
flutter build ios --release

# Web build
flutter build web
```

---

## Troubleshooting

### "Firebase not initialized" error
- Make sure `google-services.json` is in `android/app/`
- For iOS, ensure `GoogleService-Info.plist` is in `ios/Runner/`

### "Gradle build failed"
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### "CocoaPods issues" (iOS)
```bash
cd ios
pod install --repo-update
cd ..
flutter run
```

### "flutter doctor" shows issues
```bash
flutter doctor -v    # Verbose output to see what's missing
```

---

## Notes

- The app requires **Android 6.0+** (API 23) or **iOS 12.0+**
- App blocking and usage tracking features work only on **Android** (uses native platform channels)
- Location tracking requires GPS permission from the user
- Firebase project access needed if you want to modify Firestore rules or add new platforms
