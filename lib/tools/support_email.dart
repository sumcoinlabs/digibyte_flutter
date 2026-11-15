import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// The same contact experience is used by Wallet List and About.
class WalletSupportEmail {
  static const address = 'digibytewalletorg@gmail.com';

  static String bodyForVersion(String version) =>
      '''Hello DigiByte Wallet Support,

WHAT HAPPENED?
Please describe the problem or your question:

WHAT DID YOU EXPECT TO HAPPEN?

HOW CAN WE REPRODUCE IT?
List the steps you took, starting just before the problem:
1.
2.
3.

DOES THIS HAPPEN EVERY TIME?
Always / Sometimes / Only once:

ERROR MESSAGES
Copy the exact message or write None:

DEVICE DETAILS
Device model (e.g. iPhone 14 or Galaxy S24):
OS version (e.g. iOS 18 or Android 16):
DigiByte Wallet version: $version

ATTACHMENTS
Please add screenshots or a short screen recording if helpful.

WHAT HAVE YOU ALREADY TRIED? (optional)

SECURITY: Never email your recovery words, private keys, WIF, passwords,
or images that reveal them. Hide personal information before attaching images.

Thank you for helping improve DigiByte Wallet.
''';

  static Future<void> compose(BuildContext context) async {
    String version = 'Unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version} (build ${info.buildNumber})';
    } catch (_) {}
    if (!context.mounted) return;

    final mailUri = Uri.parse(
      'mailto:$address?subject=${Uri.encodeComponent('DigiByte Wallet support request')}'
      '&body=${Uri.encodeComponent(bodyForVersion(version))}',
    );
    try {
      if (await launchUrl(mailUri)) return;
    } catch (_) {}
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Contact DigiByte Wallet Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'No email app opened. You can copy our support address and email us directly.'),
            SizedBox(height: 12),
            SelectableText(address),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: address));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Copy address'),
          ),
        ],
      ),
    );
  }
}
