# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Gotan is a Flutter consumer app by Digistall for the town of Gotan. It has three features: booking a ride (Bike, Auto or Car), booking a parcel pickup, and ordering from local shops. Android (`com.digistall.gotan`) is the real target. `main.dart` calls `Firebase.initializeApp()` without options, so it relies on `android/app/google-services.json`. There is no `ios/Runner/GoogleService-Info.plist`, so Firebase init will fail on iOS until one is added.

## Commands

```bash
flutter pub get
flutter run                          # debug on connected device/emulator
flutter analyze                      # lints: package:flutter_lints/flutter.yaml
flutter test                         # all tests
flutter test test/widget_test.dart --plain-name "<test name>"   # single test
dart run build_runner build --delete-conflicting-outputs        # regenerate Hive adapters (*.g.dart)
flutter build appbundle --release    # Play Store build
flutter build apk --release
```

- **Signing:** `android/app/build.gradle.kts` reads `android/key.properties` (gitignored) unconditionally when it creates the `release` signing config. If that file is missing, Gradle configuration fails for every build type, debug included.
- **Version:** bump `version:` in `pubspec.yaml` (`1.0.4+20` = versionName+versionCode) before a release.
- **Tests:** `test/widget_test.dart` is still the default Flutter counter template. It will fail because `MyApp` has no counter and depends on Firebase, Hive and Provider setup from `main()`. No real tests exist.

## Architecture

### No service/API layer
Screens call `http` (or `dio` for directions) directly inside their `State` classes, then parse `jsonDecode` maps inline. Most API data stays as raw `Map<String, dynamic>`, and the classes in `lib/model/` are only partly used. There are two backends, defined in `lib/global/common.dart`:

- `Common.baseUrl` (`gotanbackend.digistall.in`) handles auth, user profile, rides, parcels and the shop list (`api/auth/*`, `api/user/*`, `api/shop/getallshops`, `api/counter/*`).
- `Common.digiBaseUrl` (`backend.digistall.in`) is the shared Digistall commerce backend. It serves shop catalogs (`shop`), order placement (`customer/addorder`) and order history (`customer/getcustomer`).

Endpoints are built with string concatenation (`Common.baseUrl + 'api/...'`). Both base URLs end with `/`.

### Identity and session
- No auth token or Authorization header is used. The user is identified by **phone number**, which is stored in SharedPreferences and sent in request bodies.
- `cityName: "Gotan"` is hardcoded in requests.
- SharedPreferences keys use the `gotan_` prefix: `gotan_phone_number`, `gotan_name`, `gotan_city`, `gotan_userOtp`, `gotan_orderId`. Other keys are `deviceToken` (the FCM token) and `skip` (`'skipped'` means guest mode).
- `UserProvider` defaults the phone to the sentinel `'0000000000'`. HomePage checks for that value to treat the user as logged out and send them to `PhoneInputPage`.

### Startup and auth flow
1. `main()` initializes Firebase, registers the FCM background handler, and runs `NotificationService().initialize()`. That method stores the FCM token in `deviceToken` and is a singleton in `lib/services/`.
2. Then `main()` initializes Hive, registers `CartItemAdapter`, preloads the cart and wishlist providers, and wraps the app in `MultiProvider`.
3. `SplashScreen` sends the user to `HomePage` if a phone number is saved or `skip == 'skipped'`. Otherwise it opens `PhoneInputPage`.
4. There are two login paths:
   - Firebase phone OTP: `PhoneInputPage` → `OTPVerificationPage` → `POST api/auth/authenticate` (with `deviceToken`).
   - Password login: `api/auth/loginuserwithpassword`, then `api/user/getuser`.

   Both save the user to prefs and call `UserProvider.loadFromPrefs`.

### Ride and parcel flow
`HomePage` → `LottieSplashScreen(nextPage: ...)` → `LocationPickerPage(page: 1 | 2)`. Page 1 is a ride and page 2 is a parcel.

- **Ride:** `lib/MapScreen.dart` (note: in `lib/`, not `lib/pages/`).
  1. Calls `api/user/addriderorder` and immediately `api/user/acceptBookRiderOrder`.
  2. Fare is computed on the client: `km × 10 × {Bike: 1, Auto: 2, Car: 3}`.
  3. Then goes to `LottieSplashScreenToHome(isRide: true)` → `BookingInstant`.
- **Parcel:** `MapScreenParcel` (`api/user/addParcelOrder`) → `ParcelSummaryScreen` (`acceptBookParcelOrder`) → `LottieSplashScreenToHome(isRide: false)` → `ParcelInstant`.
- **Live status:** these screens poll with `Timer.periodic(5s)` instead of push or websockets: `BookingInstant`, `ParcelInstant`, the `*DetailScreen` screens and the `*HistoryScreen` screens. Cancel the timer in `dispose`.
- **Resuming an active ride:** on launch, `HomePage` calls `api/user/getCurrentRiderOrder` and reopens an active ride.
- **Maps:** route polylines come from `lib/repo/directions_repository.dart` (Google Directions API). Place search uses Places Autocomplete inside `LocationPickerPage`.

### Shop flow
- `HomePage` lists shops from `api/shop/getallshops?cityName=Gotan`.
- Tapping a shop opens `ShopMainScreen(shopId)`, a bottom-nav shell with four tabs: Wishlist, Cart, Shop and Orders.
- The cart/checkout tab is `CheckoutScreen` in `lib/testing/CheckoutScreen.dart`. It is production code despite the directory name, and it places orders via `digiBaseUrl + 'customer/addorder'`.
- **`CartProvider`:** holds a **separate cart per store** (`Map<storeId, Map<productId, CartItem>>`) and persists it to the Hive box `storeCarts`.
- **`WishlistProvider`:** one global list, persisted to the Hive box `wishlist`.
- **Product maps:** both providers build `CartItem` from raw API product maps. The keys are `productId`, `productName`, `productPrice`, `productdiscountPrice` (lowercase `d`), `productImages`, `productUnits` and `productUnitType`.
- **`CartItem`:** a Hive type (`typeId: 0`). To add a field, use a new `@HiveField` index (never reuse or renumber one), then rerun `build_runner` to regenerate `cart_item.g.dart`.

### Other notes
- **Unused screens:** `BookingSummaryScreen`, `PhoneLoginScreen` and `UserProfilePage` are not referenced anywhere. The live ride confirmation is in `MapScreen`.
- **Hardcoded API keys:**
  - Google Maps/Places: `LocationPickerPage`, `directions_repository.dart`, and `AndroidManifest.xml` (`com.google.android.geo.API_KEY`; iOS has no Maps key configured)
  - OpenWeather: `homepage.dart`
- **Firebase config:** `lib/firebase_options.dart` is generated by FlutterFire (project `humans-of-rural-india-d2b22`, see `firebase.json`). It is not passed to `initializeApp`.
- **Notification icon:** Android local notifications use `@drawable/logo`.
- **`homepage.dart` (~1.8k lines):** holds the home UI, the drawer (`MainDrawer`), the weather widget and the permission dialogs.
