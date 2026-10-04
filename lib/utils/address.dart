/// Formats a saved delivery address for a Digistall order:
/// "Name, +91-XXXXXXXXXX, street, Near landmark, city, pincode, state, India".
///
/// The format matters to the backend: the seller email reads the customer name
/// from the first comma-separated part, and `customer/getorders` finds a
/// customer's orders by the 10-digit number inside this string.
String formatDeliveryAddress(Map<String, dynamic> a) {
  String s(String k) => (a[k] ?? '').toString().trim();
  return [
    s('name'),
    s('mobile').isEmpty ? '' : '+91-${s('mobile')}',
    s('address'),
    s('landmark').isEmpty ? '' : 'Near ${s('landmark')}',
    s('city'),
    s('pincode'),
    s('state'),
    'India',
  ].where((p) => p.isNotEmpty).join(', ');
}
