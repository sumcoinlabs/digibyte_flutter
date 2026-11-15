import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../providers/app_settings_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../tools/app_localizations.dart';
import '../../tools/app_routes.dart';
import '../../widgets/buttons.dart';
import '../../widgets/setup/setup_contrast_switch_tile.dart';
import 'setup_landing.dart';

class SetupLegalScreen extends StatefulWidget {
  const SetupLegalScreen({super.key});

  @override
  State<SetupLegalScreen> createState() => _SetupLegalScreenState();
}

class _SetupLegalScreenState extends State<SetupLegalScreen> {
  void _launchURL(String url) async {
    await canLaunchUrlString(url)
        ? await launchUrlString(
            url,
          )
        : throw 'Could not launch $url';
  }

  bool _termsAgreed = false;

  void toggleTermsHandler(bool newState) {
    setState(() {
      _termsAgreed = newState;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Container(
          color: Theme.of(context).primaryColor,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const PeerProgress(step: 5),
              SizedBox(
                height: MediaQuery.of(context).size.height / 15,
              ),
              Image.asset(
                'assets/img/setup-legal.png',
                height: MediaQuery.of(context).size.height / 4,
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height / 15,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const PeerButtonSetupBack(),
                  AutoSizeText(
                    AppLocalizations.instance.translate('setup_legal_title'),
                    minFontSize: 24,
                    maxFontSize: 28,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(
                    width: 40,
                  ),
                ],
              ),
              Container(
                width: MediaQuery.of(context).size.width > 1200
                    ? MediaQuery.of(context).size.width / 2
                    : MediaQuery.of(context).size.width,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PeerButton(
                      onPrimaryBackground: true,
                      action: () => _launchURL(
                        'https://github.com/sumcoinlabs/digibyte_flutter/blob/main/LICENSE',
                      ),
                      text: AppLocalizations.instance.translate(
                        'setup_legal_license',
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SetupContrastSwitchTile(
                        key: const Key('setupLegalConsentKey'),
                        title: AppLocalizations.instance
                            .translate('setup_legal_switch_tile'),
                        value: _termsAgreed,
                        onChanged: (newState) => toggleTermsHandler(newState),
                      ),
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 50,
              ),
              PeerButtonSetup(
                text: AppLocalizations.instance.translate('setup_finish'),
                active: _termsAgreed,
                action: () async {
                  final navigator = Navigator.of(context);
                  if (_termsAgreed == false) return;
                  final prefs = await SharedPreferences.getInstance();
                  // New seed: ensure its FIRST DigiByte wallet exists before
                  // marking setup complete. Imported seeds retain scanning.
                  if (prefs.getBool('importedSeed') != true) {
                    try {
                      final walletProvider = context.read<WalletProvider>();
                      await walletProvider.init();
                      if (walletProvider.availableWalletValues.isEmpty) {
                        await walletProvider.addWallet(
                          name: 'digibyte_0',
                          title: 'DigiByte',
                          letterCode: 'DGB',
                          isImportedSeed: false,
                          watchOnly: false,
                        );
                        if (!mounted) return;
                        final settings = context.read<AppSettingsProvider>();
                        final order = List<String>.from(settings.walletOrder);
                        if (!order.contains('digibyte_0')) {
                          settings.setWalletOrder([...order, 'digibyte_0']);
                        }
                        if (settings.notificationInterval > 0) {
                          final notifications = List<String>.from(
                              settings.notificationActiveWallets);
                          if (!notifications.contains('digibyte_0')) {
                            settings.setNotificationActiveWallets(
                              [...notifications, 'digibyte_0'],
                            );
                          }
                        }
                      }
                    } catch (_) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.instance
                              .translate('add_coin_failed')),
                        ),
                      );
                      return;
                    }
                  }
                  if (!mounted) return;
                  await prefs.setBool('setupFinished', true);
                  await navigator.pushNamedAndRemoveUntil(
                    Routes.walletList,
                    (_) => false,
                  );
                },
              ),
              const SizedBox(
                height: 60,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
