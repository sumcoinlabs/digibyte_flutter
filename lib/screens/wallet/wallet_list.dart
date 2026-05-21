import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:digibyte/tools/logger_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// IMPORTANT: This import gives you canLaunchUrlString/launchUrlString:
import 'package:url_launcher/url_launcher_string.dart';

import '../../models/available_coins.dart';
import '../../models/hive/coin_wallet.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../tools/app_localizations.dart';
import '../../tools/app_routes.dart';
import '../../tools/auth.dart';
import '../../tools/background_sync.dart';
import '../../tools/debug_log_handler.dart';
import '../../tools/periodic_reminders.dart';
import '../../tools/price_ticker.dart';
import '../../tools/session_checker.dart';
import '../../tools/share_wrapper.dart';
import '../../widgets/buttons.dart';
import '../../widgets/logout_dialog_dummy.dart'
    if (dart.library.html) '../../widgets/logout_dialog.dart';
import '../../widgets/spinning_digibyte_icon.dart';
import '../../widgets/wallet/new_wallet.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


// Remove "const" if BannerAdWidget doesn't have a const constructor
import '../../widgets/banner_ad_widget.dart';

/// Utility to format coin amounts up to 8 decimals, with commas:
String formatCoin(double amount) {
  // e.g. "123,456.78901234"
  final coinFormatter = NumberFormat("#,##0.########", "en_US");
  return coinFormatter.format(amount);
}

/// Utility to format fiat amounts to exactly two decimals, with commas:
String formatFiat(double amount) {
  // e.g. "1,234.56"
  final fiatFormatter = NumberFormat("#,##0.00", "en_US");
  return fiatFormatter.format(amount);
}

/// A simple referral dialog that asks for the user’s email:
class ReferralDialog extends StatefulWidget {
  const ReferralDialog({Key? key}) : super(key: key);

  @override
  State<ReferralDialog> createState() => _ReferralDialogState();
}

class _ReferralDialogState extends State<ReferralDialog> {
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.instance.translate('referral_dialog_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.instance.translate('referral_dialog_content'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: AppLocalizations.instance.translate('referral_email'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            AppLocalizations.instance.translate('server_settings_alert_cancel'),
          ),
        ),
        TextButton(
          onPressed: () {
            final email = _emailController.text.trim();
            // In the future: Store to Firebase or your server
            print('Referral email submitted: $email');
            Navigator.pop(context);
          },
          child: Text(
            AppLocalizations.instance.translate('continue'),
          ),
        ),
      ],
    );
  }
}

class WalletListScreen extends StatefulWidget {
  final bool fromColdStart;
  final String walletToOpenDirectly;

  const WalletListScreen({
    super.key,
    this.fromColdStart = false,
    this.walletToOpenDirectly = '',
  });

  @override
  State<WalletListScreen> createState() => _WalletListScreenState();
}

class _WalletListScreenState extends State<WalletListScreen>
    with SingleTickerProviderStateMixin {
  bool _initial = true;
  bool _showHiddenWallets = false;
  int _nOfHiddenWallets = 0;
  late bool _importedSeed;
  late WalletProvider _walletProvider;
  late Animation<double> _animation;
  late AnimationController _controller;
  late Timer _priceTimer;
  late Timer _sessionTimer;
  late AppSettingsProvider _appSettings;
  late List<CoinWallet> _activeWalletsOrdered;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,

      /// 1) AppBar
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: IconButton(
          key: const Key('appSettingsButton'),
          icon: const Icon(Icons.settings_rounded),
          onPressed: () async {
            await Navigator.pushNamed(context, Routes.appSettings);
          },
        ),
        actions: [
      /*    // 2) Referral icon
          IconButton(
            icon: const Icon(Icons.card_giftcard_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return const ReferralDialog();
                },
              );
            },
          ), */
          IconButton(
            key: const Key('newWalletIconButton'),
            onPressed: () {
              _showWalletDialog(context);
            },
            icon: const Icon(Icons.add_rounded),
          ),
          if (kIsWeb)
            IconButton(
              key: const Key('logoutButton'),
              onPressed: () async {
                if (_initial == false) {
                  await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return const LogoutDialog();
                    },
                  );
                }
              },
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),

      /// 3) Body
      body: Column(
        children: [
          /// The main content
          Expanded(
            child: _initial
                ? const Center(child: SpinningDigiByteIcon())
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        // Animated DigiByte logo area
                        AnimatedBuilder(
                          animation: _animation,
                          builder: (ctx, child) {
                            return ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 92),
                              child: Container(
                                height: _animation.value,
                                width: _animation.value,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).shadowColor,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(50.0)),
                                  border: Border.all(
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    if (!kIsWeb) {
                                      ShareWrapper.share(
                                        context: context,
                                        message: Platform.isAndroid
                                            ? 'https://play.google.com/store/apps/details?id=org.digibytewallet'
                                            : 'https://apps.apple.com/app/digibyte-wallet/id6451452746',
                                      );
                                    }
                                  },
                                  child: Image.asset(
                                    'assets/icon/dgb-logo.png',
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // "DigiByte Wallet" text
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            'DigiByte Wallet',
                            style: TextStyle(
                              letterSpacing: 1.4,
                              fontSize: 24,
                              color: Theme.of(context).colorScheme.surface,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Show either "no wallets" or the list
                        _activeWalletsOrdered.isEmpty
                            ? Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      AppLocalizations.instance.translate(
                                        'wallets_none',
                                      ),
                                      key: const Key('noActiveWallets'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontStyle: FontStyle.italic,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                      ),
                                    ),
                                    if (_importedSeed) const SizedBox(height: 20),
                                    if (_importedSeed)
                                      PeerButtonBorder(
                                        key: const Key('scanForWalletsButton'),
                                        text: AppLocalizations.instance.translate(
                                          'scan_for_wallets',
                                        ),
                                        action: () => Navigator.of(context)
                                            .pushNamed(
                                          Routes.appSettingsWalletScanner,
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                    PeerButtonBorder(
                                      text: AppLocalizations.instance.translate(
                                        'add_new_wallet',
                                      ),
                                      action: () => _showWalletDialog(context),
                                    ),
                                  ],
                                ),
                              )
                            : Expanded(
                                child: SizedBox(
                                  width: MediaQuery.of(context).size.width > 1200
                                      ? MediaQuery.of(context).size.width / 2
                                      : MediaQuery.of(context).size.width,
                                  child: ListView.builder(
                                    itemCount: _activeWalletsOrdered.length,
                                    itemBuilder: (ctx, i) {
                                      final wallet =
                                          _activeWalletsOrdered[i];
                                      final rawBalance = wallet.balance /
                                          AvailableCoins.getDecimalProduct(
                                            identifier: wallet.name,
                                          );
                                      final coinString = formatCoin(rawBalance);
                                      final showFiat = wallet.letterCode !=
                                              'tDGB' &&
                                          _appSettings
                                              .selectedCurrency.isNotEmpty;

                                      double fiatDouble = 0.0;
                                      if (showFiat) {
                                        fiatDouble = PriceTicker.renderPrice(
                                          rawBalance,
                                          _appSettings.selectedCurrency,
                                          wallet.letterCode,
                                          _appSettings.exchangeRates,
                                        );
                                      }

                                      return Card(
                                        elevation: 0,
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 16,
                                        ),
                                        color:
                                            Theme.of(context).colorScheme.surface,
                                        child: Column(
                                          children: [
                                            InkWell(
                                              onTap: () async {
                                                context.loaderOverlay.show();
                                                await Navigator.of(context)
                                                    .pushNamed(
                                                  Routes.walletHome,
                                                  arguments: {
                                                    'wallet': wallet,
                                                  },
                                                );
                                              },
                                              child: ListTile(
                                                leading: Stack(
                                                  children: [
                                                    CircleAvatar(
                                                      backgroundColor:
                                                          Colors.white,
                                                      child: Image.asset(
                                                        AvailableCoins
                                                            .getSpecificCoin(
                                                          wallet.name,
                                                        ).iconPath,
                                                        width: 20,
                                                      ),
                                                    ),
                                                    if (wallet.watchOnly)
                                                      const Positioned(
                                                        right: 0,
                                                        bottom: 0,
                                                        child: Icon(
                                                          Icons.visibility,
                                                          size: 16,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    if (wallet.hidden)
                                                      const Positioned(
                                                        right: 0,
                                                        top: 0,
                                                        child: Icon(
                                                          Icons.visibility_off,
                                                          size: 16,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                title: Text(
                                                  wallet.title,
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    // Larger font for coin
                                                    Text(
                                                      '$coinString ${wallet.letterCode}',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color:
                                                            Colors.blue[100],
                                                      ),
                                                    ),
                                                    // If showFiat, show it below
                                                    if (showFiat)
                                                      Text(
                                                        '${formatFiat(fiatDouble)} ${_appSettings.selectedCurrency}',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color:
                                                              Colors.blue[50],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                trailing: Icon(
                                                  Icons
                                                      .arrow_forward_ios_rounded,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .secondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                    /*    /// **Chart Placeholder** (under the list of wallets)
                        const SizedBox(height: 20),
                        Container(
                          height: 200, // or any height
                          width: double.infinity,
                          color: Colors.grey.withOpacity(0.1), // placeholder bg
                          alignment: Alignment.center,
                          child: const Text(
                            'CHART PLACEHOLDER\n(Consider using fl_chart!)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        ), */

                        const SizedBox(height: 20),
                        // Banner ad widget (remove "const")
                        SizedBox(
                          height: 60, // adjust if needed
                         child: BannerAdWidget(), // no const
                        ),
                      ],
                    ),
                  ),
          ),

          /// 4) Bottom bar with social icons
          Container(
            //  <--- Set a slightly visible background so icons don't vanish
            color: Colors.black54,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
              // X (Twitter) - try deep link first, fallback to x.com
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.xTwitter), // X logo
                    color: Colors.white,
                    onPressed: () async {
                    // Attempt the X (Twitter) scheme first
                    const xScheme = 'twitter://user?screen_name=DigiByteWallet';
                    if (await canLaunchUrlString(xScheme)) {
                      await launchUrlString(xScheme);
                    } else {
                      // Fallback to x.com
                      const fallback = 'https://x.com/DigiByteWallet';
                      if (await canLaunchUrlString(fallback)) {
                        await launchUrlString(fallback);
                      }
                    }
                  },
                ),
                // YouTube - try deep link first, fallback to youtube.com
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.youtube), // Standard YouTube logo
                  color: Colors.white,
                  iconSize: 24, // Consistent size with X logo
                  tooltip: 'Visit DigiByteWallet on YouTube', // Accessibility
                  style: IconButton.styleFrom(
                    shape: const CircleBorder(),
                    backgroundColor: Colors.red, // YouTube branding color
                  ),
                  onPressed: () async {
                    // Attempt YouTube deep link with channel ID
                    const youtubeScheme = 'youtube://channel/UC1234567890'; // Replace with actual channel ID
                    if (await canLaunchUrlString(youtubeScheme)) {
                      await launchUrlString(youtubeScheme, mode: LaunchMode.externalApplication);
                    } else {
                      // Fallback to YouTube web URL
                      const fallback = 'https://www.youtube.com/@DigiByteWallet';
                      if (await canLaunchUrlString(fallback)) {
                        await launchUrlString(fallback, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                ),
            /*    // Telegram - "tg://resolve?domain=sumcoins"
                IconButton(
                  icon: Icon(Icons.chat_bubble_rounded),
                  color: Colors.white,
                  onPressed: () async {
                    const telegramScheme = 'tg://resolve?domain=sumcoins';
                    if (await canLaunchUrlString(telegramScheme)) {
                      await launchUrlString(telegramScheme);
                    } else {
                      final fallback = 'https://t.me/sumcoins';
                      if (await canLaunchUrlString(fallback)) {
                        await launchUrlString(fallback);
                      }
                    }
                  },
                ), */
                // Email
                IconButton(
                  icon: Icon(Icons.email_rounded),
                  color: Colors.white,
                  onPressed: () async {
                    final subject = Uri.encodeComponent(
                      'DigiByte Wallet - In App Mail',
                    );
                    final body = Uri.encodeComponent(
                      'Hello Support,\n\n'
                      '1. Describe your issue or question:\n'
                      '2. Device Type:\n'
                      '3. Have you seen any error messages?:\n\n'
                      '**Please do not delete these questions, only reply to them!**\n'
                      '**Reminder: Negative app store reviews will not help get an answer any faster.**\n',
                    );
                    final mailto =
                        'mailto:digibytewalletorg@gmail.com?subject=$subject&body=$body';

                    if (await canLaunchUrlString(mailto)) {
                      await launchUrlString(mailto);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() async {
    if (_initial) {
      _appSettings = Provider.of<AppSettingsProvider>(context);
      _walletProvider = Provider.of<WalletProvider>(context);
      final navigator = Navigator.of(context);
      final modalRoute = ModalRoute.of(context);

      try {
        await _appSettings.init();
        await _walletProvider.init();
        await _orderWallets();
        final prefs = await SharedPreferences.getInstance();
        _importedSeed = prefs.getBool('importedSeed') == true;
      } catch (e) {
        await _handleInitError(e);
      } finally {
        setState(() {
          _initial = false;
        });
      }

      // Price ticker
      if (_appSettings.selectedCurrency.isNotEmpty) {
        PriceTicker.checkUpdate(_appSettings);
        _priceTimer = Timer.periodic(
          const Duration(hours: 1),
          (_) {
            PriceTicker.checkUpdate(_appSettings);
          },
        );
      }

      if (!kIsWeb) {
        _triggerChangeLogCheck(navigator, _appSettings.buildIdentifier);

        // Periodic reminders
        if (_activeWalletsOrdered.isNotEmpty) {
          if (await _checkReminder() == true) {
            return;
          }
        }
      } else {
        _sessionTimer = Timer.periodic(
          const Duration(minutes: 10),
          (timer) async {
            if (await checkSessionExpired()) {
              if (mounted) {
                Navigator.of(context).pop();
              }
              LogoutDialog.reloadWindow();
            }
          },
        );
      }

      var fromScan = false;
      if (modalRoute?.settings.arguments != null) {
        var map = modalRoute!.settings.arguments as Map;
        fromScan = map['fromScan'] ?? false;
      }
      if (widget.fromColdStart == true &&
          _appSettings.authenticationOptions!['walletList']!) {
        if (mounted) {
          await Auth.requireAuth(
            context: context,
            biometricsAllowed: _appSettings.biometricsAllowed,
            canCancel: false,
          );
        }
      } else if (fromScan == false) {
        // Background tasks
        if (_appSettings.notificationInterval > 0) {
          await BackgroundSync.init(
            notificationInterval: _appSettings.notificationInterval,
          );
        }

        // find default wallet
        CoinWallet? defaultWallet;
        if (widget.walletToOpenDirectly.isNotEmpty) {
          defaultWallet = _activeWalletsOrdered.firstWhereOrNull(
            (elem) => elem.name == widget.walletToOpenDirectly,
          );
        } else {
          defaultWallet = _activeWalletsOrdered.firstWhereOrNull(
            (elem) => elem.letterCode == _appSettings.defaultWallet,
          );
        }

        if (_activeWalletsOrdered.length == 1 &&
            widget.walletToOpenDirectly.isEmpty) {
          if (!kIsWeb) {
            if (mounted) {
              context.loaderOverlay.show();
            }
            await navigator.pushNamed(
              Routes.walletHome,
              arguments: {'wallet': _activeWalletsOrdered.first},
            );
          }
        } else if (_activeWalletsOrdered.length > 1 ||
            widget.walletToOpenDirectly.isNotEmpty) {
          if (defaultWallet != null) {
            if (mounted) {
              context.loaderOverlay.show();
            }
            if (!kIsWeb) {
              await navigator.pushNamed(
                Routes.walletHome,
                arguments: {'wallet': defaultWallet},
              );
            }
          }
        }
      }
    }
    await _orderWallets();
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    if (_appSettings.selectedCurrency.isNotEmpty) {
      _priceTimer.cancel();
    }
    if (kIsWeb) {
      _sessionTimer.cancel();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween(begin: 88.0, end: 92.0).animate(_controller);
    _controller.repeat(reverse: true);
    super.initState();
  }

  Future<bool> _checkReminder() async {
    return await PeriodicReminders.checkReminder(_appSettings, context);
  }

  Future<void> _handleInitError(Object e) async {
    LoggerWrapper.logError(
      'WalletListScreen',
      'didChangeDependencies',
      e.toString(),
    );
    await initDebugLogHandler();
    FlutterLogs.exportLogs();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.instance.translate('secure_storage_app_bar_title'),
            textAlign: TextAlign.center,
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _orderWallets() async {
    final values = _walletProvider.availableWalletValues;
    final order = _appSettings.walletOrder;
    values.sort((a, b) => order.indexOf(a.name).compareTo(order.indexOf(b.name)));
    _activeWalletsOrdered = _showHiddenWallets
        ? values
        : values.where((wallet) => !wallet.hidden).toList();
    _nOfHiddenWallets = values.where((wallet) => wallet.hidden).length;
  }

  void _showWalletDialog(BuildContext context) {
    if (_initial == false) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return const NewWalletDialog();
        },
      );
    }
  }

  void _toggleHiddenWallets() {
    setState(() {
      _showHiddenWallets = !_showHiddenWallets;
    });
    _orderWallets();
  }

  void _triggerChangeLogCheck(NavigatorState navigator, String buildId) async {
    var packageInfo = await PackageInfo.fromPlatform();
    if (packageInfo.buildNumber != buildId) {
      await navigator.pushNamed(Routes.changeLog);
      _appSettings.setBuildIdentifier(packageInfo.buildNumber);
    }
  }
}
