import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../global/common.dart';
import '../widgets/ui.dart';

/// Opens [url] in an external app, showing [failMessage] if nothing can handle it.
Future<void> openExternal(BuildContext context, String url, {String failMessage = 'Could not open the link'}) async {
  final uri = Uri.parse(url);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showAppSnack(context, failMessage, error: true);
  } catch (_) {
    if (context.mounted) showAppSnack(context, failMessage, error: true);
  }
}

Future<void> callNumber(BuildContext context, String phone) {
  final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) {
    showAppSnack(context, 'Phone number not available', error: true);
    return Future.value();
  }
  return openExternal(context, 'tel:$digits', failMessage: 'Could not open the dialer');
}

Future<void> openWhatsApp(BuildContext context, String phone, {String text = ''}) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) digits = '91$digits';
  final query = text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}';
  return openExternal(context, 'https://wa.me/$digits$query', failMessage: 'WhatsApp is not available');
}

Future<void> emailSupport(BuildContext context) => openExternal(
      context,
      Uri(scheme: 'mailto', path: Common.supportEmail, query: 'subject=Gotan%20app').toString(),
      failMessage: 'No email app found',
    );
