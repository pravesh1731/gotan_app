# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Gotan is a Flutter consumer app by Digistall for the town of Gotan. It mirrors the gotan.in website (repo `Siyag-Rural-Market-Private-Limited/gotan`) and has three features: booking a ride (Bike, Auto or Car), booking a parcel pickup, and ordering from local shops. Android (`com.digistall.gotan`) is the real target. On Android, `main.dart` calls `Firebase.initializeApp()` without options, so it relies on `android/app/google-services.json`; on web it passes `DefaultFirebaseOptions`. There is no `ios/Runner/GoogleService-Info.plist`, so Firebase init fails on iOS (the app catches this and keeps running without OTP login or push).

## Commands

```bash
flutter pub get
flutter run                          # debug on connected device/emulator
flutter analyze                      # lints: package:flutter_lints/flutter.yaml (CamelCase file_names infos are expected)
flutter test                         # all tests
flutter test test/models_test.dart --plain-name "<test name>"   # single test
dart run build_runner build --delete-conflicting-outputs        # regenerate Hive adapters (*.g.dart)
flutter build appbundle --release    # Play Store build
flutter build apk --release
```

- **Signing:** `android/app/build.gradle.kts` reads `android/key.properties` (gitignored) unconditionally when it creates the `release` signing config. If that file is missing, Gradle configuration fails for every build type, debug included.
- **Version:** bump `version:` in `pubspec.yaml` (`1.0.4+20` = versionName+versionCode) before a release.
- **Tests:** `test/models_test.dart` covers fares, booking status, store/order parsing and the order address format. There are no widget tests.
- **Web preview:** `flutter build web` works for checking UI, but Google Maps screens need a Maps JS script in `web/index.html`, and phone OTP login is Android-only.

## Architecture

### Backends and the API layer
All HTTP goes through `lib/services/api.dart` (`Api.*` static methods). It decodes JSON, maps network failures and non-2xx responses to `ApiException` with the backend's `message`/`error` text. There are two backends, defined in `lib/global/common.dart` (both base URLs end with `/`):

- `Common.baseUrl` (`gotanbackend.digistall.in`, repo `gotanbackend`) handles auth, user profile, rides, parcels, the shop list, the visit counter and rider dispatch for shop orders (`api/auth/*`, `api/user/*`, `api/shop/getallshops`, `api/counter/gotanCounter`, `api/digiorder/shopdigiorder`).
- `Common.digiBaseUrl` (`backend.digistall.in`, repo `hri-backend`) is the shared Digistall commerce backend: store catalogs (`POST shop`), order placement (`customer/addorder`) and order lookup (`customer/getorders`).

Google Directions is called through `lib/repo/directions_repository.dart` (dio); Places Autocomplete/Details are called from `LocationPickerPage`.

### Identity and session
- No auth token is used. The user is identified by **phone number**, stored in SharedPreferences and sent in request bodies.
- `lib/services/session.dart` owns all prefs keys: `gotan_phone_number`, `gotan_name`, `gotan_city`, `gotan_userOtp`, `gotan_profileImage`, `gotan_orderId` (active ride), `gotan_parcelOrderId` (active parcel), `gotan_shopOrderIds`, `saved_addresses`, `deviceToken` (FCM token) and `skip` (`'skipped'` = guest mode). `Session.logout()` clears everything except `deviceToken`.
- `UserProvider` defaults the phone to the sentinel `Common.guestPhone` (`'0000000000'`); use `isLoggedIn`. `refresh()` reloads name, city, ride OTP and photo from `api/user/getuser`.
- `gotan_userOtp` is the 4-digit code the rider must enter (backend compares it to `user.userOtp`) before a ride/parcel moves to "In Transit". Show it on tracking screens.

### Startup and auth flow
1. `main()` initializes Firebase and `NotificationService` (stores the FCM token, re-syncs it on refresh, and exposes `messages`, a stream of foreground pushes), then Hive, the cart/wishlist providers and `UserProvider.load()`.
2. `SplashScreen` opens `HomePage` if logged in or skipped, else `PhoneInputPage`.
3. Login paths both end in `finishLogin()` (`lib/pages/login_flow.dart`): fetch `getuser`, save it, reset the FCM token, ask for a name if the backend still has `"No name"` (`NameCaptureScreen` → `api/auth/newname`), then go home.
   - Firebase phone OTP: `PhoneInputPage` → `OTPVerificationPage` → `api/auth/authenticate` (creates the user if new; for new users the response is `{data: user}`, not the profile, which is why `getuser` is always called afterwards).
   - Password login: `api/auth/loginuserwithpassword` (404 = no account, 401 = wrong password).

### Ride and parcel flow
`startBooking()` (`lib/pages/booking_flow.dart`) checks login, reopens an active booking of that kind, and checks location permission → `LocationPickerPage(kind)` → `BookingConfirmScreen` → `BookingTrackingScreen`.

- **Confirm:** `Api.createBooking` (`addriderorder` / `addParcelOrder`) then `Api.confirmBooking` (`acceptBookRiderOrder` / `acceptBookParcelOrder?cityName=<user's stored city>`; the backend looks the user up by phone *and* city). If confirm fails the draft is rejected.
- **Fares** (`lib/utils/fare.dart`, same as the website): ride `round(km × {Bike 10, Auto 20, Car 30})`, parcel `ceil(km × 10)`. Always compute from `Directions.distanceMeters`, never from the display text. If Directions fails, the screen falls back to straight-line × 1.3 and labels it approximate.
- **Status** comes from `Booking.stage` (`lib/model/booking.dart`), derived from `user` (Pending/accepted/rejected), `riderAccepted`, `acceptedUserOtp` and `riderStatus`. Cancel = `rejectBook*Order`, allowed only before a rider accepts. (The backend's reject only updates the user's copy; the rider dashboard can still list it.)
- **Live status:** `BookingTrackingScreen` polls `getCurrent*Order` every 5 s and also refreshes on `NotificationService().messages`. It doubles as the detail screen from `BookingHistoryScreen` (Rides/Parcels tabs over `myRiderOrder` / `myParcelOrder`). Cancel timers in `dispose`.
- **Invoice:** `lib/utils/invoice.dart` (pdf + printing, Inter font for the ₹ glyph).

### Shop flow
- `HomePage` lists shops from `api/shop/getallshops` (filters: `search`, `tag`, `format`; search also returns `matchedProducts`).
- `ShopMainScreen(shopId)` loads the Digistall store once (`Api.getStore` → `Store`) and shows Shop / Wishlist / Cart / Orders tabs in an `IndexedStack`. If the store has no visible products it offers the shop's storefront `https://<shopId>.digistall.in`, as the website does.
- **Models:** `Store`, `Product` (`lib/model/store.dart`, null-safe, `num` prices, variants as `size → color → {stock}`), `ShopOrder` (`lib/model/shop_order.dart`, groups the per-product records by `orderId`).
- **`CartProvider`:** one cart per store (`Map<storeId, Map<lineKey, CartItem>>`, Hive box `storeCarts`). `syncWithStore()` refreshes prices/stock and drops removed products. Quantity is capped at stock because `customer/addorder` returns 409 if any line exceeds stock or mixes shops.
- **`WishlistProvider`:** Hive box `wishlist`; items remember `storeId` and are matched against the live catalog.
- **Checkout** (`lib/pages/CheckoutScreen.dart`): sends `{email: 'guest@store.com', deviceToken: <seller FCM token from the store>, orders: [...]}`. Each line carries `productCount`, `onePiecePrice`, `coupontotal` (line total), `totalCartValue` (grand total), category `gst`, `deliveryFee` (`store.deliverPp`), `paymentMethod` `COD`/`UPI` and the address from `formatDeliveryAddress()` (`lib/utils/address.dart`). Keep that format: the seller email reads the name from the first comma part, and `customer/getorders` finds orders by the 10-digit phone inside it. Returned order ids are saved in `gotan_shopOrderIds` and also sent to `getorders`.
- **`CartItem`:** a Hive type (`typeId: 0`). To add a field, use a new `@HiveField` index with a `defaultValue` (never reuse or renumber one), then rerun `build_runner`. Do not name a member `key`: `HiveObject.key` is the box key. Use `lineKey`.

### UI
- Design tokens mirror the website's `tailwind.config.js` in `lib/theme/app_theme.dart` (`AppColors.teal #159A9C`, `navy #16324F`, `yellow #F4D35E`, …). Fonts Inter and Outfit are bundled in `assets/fonts`.
- Shared widgets live in `lib/widgets/ui.dart` (`AppCard`, `AppButton`, `StatusChip`, `EmptyState`, `InfoRow`, `RouteSummary`, `NetImage`, `showAppSnack`, `confirmDialog`, `rupees`). `NetImage` upgrades `http://` Cloudinary URLs to https because Android blocks cleartext.
- URL/phone/WhatsApp launching: `lib/utils/launch.dart`. The manifest `<queries>` includes `tel`, `mailto` and `upi` so `launchUrl` works on Android 11+.

### Other notes
- **Hardcoded API keys:** Google Maps/Places in `Common.mapsApiKey` and `AndroidManifest.xml` (`com.google.android.geo.API_KEY`; iOS has no Maps key); OpenWeather in `Common.weatherApiKey`.
- **Firebase config:** `lib/firebase_options.dart` is generated by FlutterFire (project `humans-of-rural-india-d2b22`, see `firebase.json`).
- **Notification icon:** Android local notifications use `@drawable/logo`.
