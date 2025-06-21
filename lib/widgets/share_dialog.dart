import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void showShareDialog(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: const EdgeInsets.only(top: 20, left: 24, right: 8),
        contentPadding: const EdgeInsets.only(left: 24, right: 24, top: 14, bottom: 20),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Share this product',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.blueAccent),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              readOnly: true,
              controller: TextEditingController(text: url),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy, color: Colors.blueAccent),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied')),
                    );
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _shareOption(
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
                  label: 'WhatsApp',
                  onTap: () async {
                    final whatsappUrl = Uri.parse("https://wa.me/?text=$url");
                    if (await canLaunchUrl(whatsappUrl)) {
                      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                _shareOption(
                  icon: const Icon(Icons.facebook, color: Colors.blue),
                  label: 'Facebook',
                  onTap: () async {
                    final facebookUrl = Uri.parse("https://www.facebook.com/sharer/sharer.php?u=$url");
                    if (await canLaunchUrl(facebookUrl)) {
                      await launchUrl(facebookUrl, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                _shareOption(
                  icon: const Icon(Icons.email, color: Colors.grey),
                  label: 'Email',
                  onTap: () async {
                    final emailUrl = Uri.parse("mailto:?subject=Check this out&body=$url");
                    if (await canLaunchUrl(emailUrl)) {
                      await launchUrl(emailUrl);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Widget _shareOption({required Widget icon, required String label, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade100,
          ),
          child: icon,
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}
