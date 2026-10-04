class Common {
  static const String baseUrl = "https://gotanbackend.digistall.in/";
  static const String digiBaseUrl = "https://backend.digistall.in/";

  static const String cityName = "Gotan";
  static const String websiteUrl = "https://gotan.in";
  static const String supportPhone = "9461852060";
  static const String supportEmail = "humansofruralindia@gmail.com";
  static const String digistallUrl = "https://digistall.in/";
  static const String riderUrl = "https://rider.digistall.in/";
  static const String privacyUrl = "https://gotan.in/privacy-policy";
  static const String termsUrl = "https://digistall.in/terms_and_conditions";

  static const String mapsApiKey = "AIzaSyB-HKYA7Ps8XvDkW4FBY6DR25Yk9yOnteQ";
  static const String weatherApiKey = "c76914cee1a87f8a02128c92786eecd3";

  /// Sentinel phone used by [UserProvider] when nobody is logged in.
  static const String guestPhone = "0000000000";

  /// Digistall storefront for a shop, used when the shop has no in-app catalog.
  static String storefrontUrl(String shopId) => "https://$shopId.digistall.in";
}
