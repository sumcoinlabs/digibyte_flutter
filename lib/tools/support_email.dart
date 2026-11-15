import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// The same contact experience is used by Wallet List and About.
class WalletSupportEmail {
  static const address = 'digibytewalletorg@gmail.com';

  /// Pure formatter so the support message is easy to unit-test.
  /// No unique device identifiers, wallet keys, addresses or balances.
  static String bodyForDetails({
    required String appVersion,
    required String device,
    required String operatingSystem,
  }) =>
      '''Hi DigiByte Wallet Support,

I need help with:
[Briefly tell us what happened or what you need help with.]

What were you doing at the time?
[Optional: the screen or action you were using.]

Did you see an error?
[Paste the message here, or say No.]

A screenshot or short recording may help (optional).

--- Device details (added automatically) ---
App: DigiByte Wallet $appVersion
Device: $device
Software: $operatingSystem

Please never share your recovery phrase, private keys or passwords.
Thanks!
''';

  static Future<void> compose(BuildContext context) async {
    String version = 'Unavailable';
    String device = 'Unavailable';
    String operatingSystem = 'Unavailable';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version} (build ${info.buildNumber})';
    } catch (_) {}

    // Device model and OS version are non-unique diagnostics. No device IDs.
    try {
      if (!kIsWeb && Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        device = info.modelName.isNotEmpty ? info.modelName : info.model;
        operatingSystem = '${info.systemName} ${info.systemVersion}';
      } else if (!kIsWeb && Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        device = '${info.manufacturer} ${info.model}'.trim();
        operatingSystem = 'Android ${info.version.release}';
      }
    } catch (_) {
      if (!kIsWeb) operatingSystem = Platform.operatingSystemVersion;
    }
    if (!context.mounted) return;

    final mailUri = Uri.parse(
      'mailto:$address?subject=${Uri.encodeComponent('DigiByte Wallet support request')}'
      '&body=${Uri.encodeComponent(bodyForDetails(appVersion: version, device: device, operatingSystem: operatingSystem))}',
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
