import 'dart:io';
import 'dart:async'; // For debounce

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/connection_provider.dart';
import '../../tools/share_wrapper.dart';
import '../../providers/wallet_provider.dart';
import '../../tools/app_localizations.dart';
import '../../models/available_coins.dart';
import '../../models/coin.dart';
import '../../models/hive/coin_wallet.dart';
import '../../widgets/buttons.dart';
import '../../widgets/double_tab_to_clipboard.dart';
import '../../widgets/service_container.dart';
import '../../widgets/wallet/wallet_balance_header.dart';
import '../../tools/price_ticker.dart';

class ReceiveTab extends StatefulWidget {
  final String unusedAddress;
  final BackendConnectionState connectionState;
  final CoinWallet wallet;

  const ReceiveTab({
    required this.unusedAddress,
    required this.connectionState,
    required this.wallet,
    super.key,
  });

  @override
  State<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<ReceiveTab> {
  bool _initial = true;
  final amountController = TextEditingController();
  final labelController = TextEditingController();
  final usdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _amountKey = GlobalKey<FormFieldState>();
  final _labelKey = GlobalKey<FormFieldState>();
  late Coin _availableCoin;
  String? _qrString;
  Map<String, dynamic> exchangeRates = {};
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchExchangeRates();
    amountController.addListener(_onAmountChanged);
    usdController.addListener(_onUsdChanged);
    labelController.addListener(_onLabelChanged);
  }

  @override
  void didChangeDependencies() {
    if (_initial) {
      _availableCoin = AvailableCoins.getSpecificCoin(widget.wallet.name);
      stringBuilder();
      setState(() {
        _initial = false;
      });
    }
    super.didChangeDependencies();
  }

  Future<void> _fetchExchangeRates() async {
    exchangeRates = await PriceTicker.getDataFromTicker();
    setState(() {});
  }

  void _onAmountChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      _updateUsdAmount();
      stringBuilder();
    });
  }

  void _onUsdChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      _updateCoinAmount();
      stringBuilder();
    });
  }

  void _onLabelChanged() {
    stringBuilder();
  }

  void _updateUsdAmount() {
    if (amountController.text.isEmpty) {
      usdController.text = '';
    } else {
      final coinAmount = double.tryParse(amountController.text);
      if (coinAmount != null &&
          exchangeRates.containsKey(widget.wallet.letterCode)) {
        final usdAmount = coinAmount * exchangeRates[widget.wallet.letterCode];
        final formattedUsdAmount = NumberFormat("#,##0.00").format(usdAmount);
        if (usdController.text != formattedUsdAmount) {
          usdController.value = TextEditingValue(
            text: formattedUsdAmount,
            selection: TextSelection.collapsed(
              offset: formattedUsdAmount.length,
            ),
          );
        }
      }
    }
  }

  void _updateCoinAmount() {
    final usdText = usdController.text.replaceAll(RegExp(r'[^\d.]'), '');
    if (usdText.isEmpty) {
      amountController.text = '';
    } else {
      final usdAmount = double.tryParse(usdText);
      if (usdAmount != null &&
          exchangeRates.containsKey(widget.wallet.letterCode)) {
        final coinAmount = usdAmount / exchangeRates[widget.wallet.letterCode];
        final formattedCoinAmount = coinAmount
            .toStringAsFixed(6)
            .replaceAll(RegExp(r'0*$'), '')
            .replaceAll(RegExp(r'\.$'), '');
        if (amountController.text != formattedCoinAmount) {
          amountController.value = TextEditingValue(
            text: formattedCoinAmount,
            selection:
                TextSelection.collapsed(offset: formattedCoinAmount.length),
          );
        }
      }
    }
  }

  void stringBuilder() {
    final convertedValue = amountController.text.isEmpty
        ? 0
        : double.parse(amountController.text.replaceAll(',', '.'));
    final label = labelController.text;
    var builtString = '';

    if (convertedValue == 0) {
      builtString = '${_availableCoin.uriCode}:${widget.unusedAddress}';
      if (label.isNotEmpty) {
        builtString =
            '${_availableCoin.uriCode}:${widget.unusedAddress}?label=$label';
      }
    } else {
      builtString =
          '${_availableCoin.uriCode}:${widget.unusedAddress}?amount=$convertedValue';
      if (label.isNotEmpty) {
        builtString =
            '${_availableCoin.uriCode}:${widget.unusedAddress}?amount=$convertedValue&label=$label';
      }
    }
    setState(() {
      _qrString = builtString;
    });
  }

  RegExp getValidator(int fractions) {
    // Example: up to `fractions` decimal places
    final expression = r'^([1-9]{1}[0-9]{0,' +
        fractions.toString() +
        r'}(,[0-9]{3})*(.[0-9]{0,' +
        fractions.toString() +
        r'})?|[1-9]{1}[0-9]{0,}(.[0-9]{0,' +
        fractions.toString() +
        r'})?|0(.[0-9]{0,' +
        fractions.toString() +
        r'})?|(.[0-9]{1,' +
        fractions.toString() +
        r'})?)$';
    return RegExp(expression);
  }

  /// Themed AlertDialog so text is visible in both light & dark mode.
  void launchURL(String url) async {
    final defaultTextColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          titleTextStyle: TextStyle(
            color: defaultTextColor,
            fontSize: Theme.of(context).textTheme.titleLarge?.fontSize ?? 20,
            fontWeight:
                Theme.of(context).textTheme.titleLarge?.fontWeight ??
                    FontWeight.w500,
          ),
          contentTextStyle: TextStyle(
            color: defaultTextColor,
            fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize ?? 16,
            fontWeight:
                Theme.of(context).textTheme.bodyMedium?.fontWeight ??
                    FontWeight.normal,
          ),
          title: Text(
            AppLocalizations.instance.translate('buy_digibyte_dialog_title'),
          ),
          content: Text(
            AppLocalizations.instance.translate('buy_digibyte_dialog_content'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.instance
                    .translate('server_settings_alert_cancel'),
              ),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await canLaunchUrlString(url)
                    ? await launchUrlString(url)
                    : throw 'Could not launch $url';
                navigator.pop();
              },
              child: Text(
                AppLocalizations.instance.translate('continue'),
              ),
            ),
          ],
        );
      },
    );
  }

  /// -----------
  /// EXCHANGE LOGIC: SIMPLIFIED PLATFORM CHECKS
  /// -----------
  Widget renderPurchaseButtons() {
    // Only for DGB (change letterCode if you want SUM, LTC, etc.)
    if (widget.wallet.letterCode != 'DGB') {
      return const SizedBox();
    }

    // 1) Always show faucet for DGB:
    final List<Widget> sections = [];

    sections.add(
      PeerContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            PeerServiceTitle(
              title: AppLocalizations.instance.translate('receive_obtain'),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.instance.translate('receive_website_faucet'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 20),
            PeerButton(
              text: AppLocalizations.instance.translate('receive_faucet'),
              action: () {
                launchURL('https://digibytewallet.org/faucet/');
              },
            ),
          ],
        ),
      ),
    );

/*    // 2) Exchange section:

    // 1. Declare three booleans. Switch them to true/false as desired.
    bool showExchangeOnIos = true;     // Show exchange on iOS?
    bool showExchangeOnAndroid = true;  // Show exchange on Android?
    bool showExchangeOnWeb = true;     // Show exchange on Web?

    // 2. Detect the current platform in a simple way:
    bool isIos = Platform.isIOS;
    bool isAndroid = Platform.isAndroid;
    bool isWeb = kIsWeb;

    // 3. Decide if we show the Exchange:
    bool showExchange =
        (isIos && showExchangeOnIos) ||
        (isAndroid && showExchangeOnAndroid) ||
        (isWeb && showExchangeOnWeb);

    // 4. If we decided to show it, add the Exchange UI to `sections`.
    if (showExchange) {
      sections.add(const SizedBox(height: 20));
      sections.add(
        PeerContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              PeerServiceTitle(
                title: AppLocalizations.instance.translate('buy_digibyte'),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.instance.translate('receive_website_description'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 20),
              PeerButton(
                text: AppLocalizations.instance.translate('receive_website_credit'),
                action: () {
                  launchURL('https://sumcoin.org/buy');
                },
              ),
              const SizedBox(height: 20),
              PeerButton(
                text: AppLocalizations.instance.translate('receive_website_exchandes'),
                action: () {
                  launchURL('https://sumcoin.org/exchanges');
                },
              ),
            ],
          ),
        ),
      );
    } */

    return Column(children: sections);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top wallet balance bar
        WalletBalanceHeader(widget.connectionState, widget.wallet),
        ListView(
          children: [
            SizedBox(
              height: widget.wallet.unconfirmedBalance > 0 ? 125 : 110,
            ),
            const SizedBox(height: 50),
            Container(
              height: 30,
              color: Colors.transparent,
            ),
            Align(
              child: PeerContainer(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      PeerServiceTitle(
                        title: AppLocalizations.instance
                            .translate('wallet_bottom_nav_receive'),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(4),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: FittedBox(
                            child: DoubleTabToClipboard(
                              withHintText: false,
                              clipBoardData: widget.unusedAddress,
                              child: SelectableText(
                                widget.unusedAddress,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: widget.unusedAddress),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Address copied to clipboard',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 18), // Adjust icon size here
                        label: const Text(
                          'Copy Address',
                          style: TextStyle(fontSize: 14), // Adjust font size here
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_qrString != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: _qrString!,
                            size: 240.0,
                            padding: const EdgeInsets.all(8),
                            embeddedImage: AssetImage(_availableCoin.iconPath),
                            embeddedImageStyle: const QrEmbeddedImageStyle(
                              size: Size(50, 50),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text(
                        AppLocalizations.instance
                            .translate('receive_requested_amount'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Image.asset(
                            _availableCoin.iconPath,
                            width: 25,
                            height: 25,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              textInputAction: TextInputAction.done,
                              key: _amountKey,
                              controller: amountController,
                              onChanged: (String newString) {
                                _onAmountChanged();
                              },
                              autocorrect: false,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  getValidator(_availableCoin.fractions),
                                ),
                              ],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Coin Amount',
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return AppLocalizations.instance
                                      .translate('receive_enter_amount');
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.wallet.letterCode,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.attach_money,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              textInputAction: TextInputAction.done,
                              controller: usdController,
                              onChanged: (String newString) {
                                _onUsdChanged();
                              },
                              autocorrect: false,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(
                                    r'^\$?(\d+|\d{1,3}(,\d{3})*)(\.\d{0,2})?$',
                                  ),
                                ),
                              ],
                              decoration: InputDecoration(
                                border: InputBorder.none,
                              //  prefixText: '\$', // Add dollar sign
                                hintText: 'USD Amount',
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'USD',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        textInputAction: TextInputAction.done,
                        key: _labelKey,
                        controller: labelController,
                        autocorrect: false,
                        onChanged: (String newString) {
                          stringBuilder();
                        },
                        decoration: InputDecoration(
                          icon: Icon(
                            Icons.bookmark,
                            color: Theme.of(context).primaryColor,
                          ),
                          labelText: AppLocalizations.instance
                              .translate('send_label'),
                        ),
                        maxLength: 32,
                      ),
                      const SizedBox(height: 30),
                      const SizedBox(height: 8),
                      PeerButton(
                        text: AppLocalizations.instance.translate('receive_share'),
                        action: () async {
                          if (labelController.text.isNotEmpty) {
                            context.read<WalletProvider>().updateOrCreateAddressLabel(
                                  identifier: widget.wallet.name,
                                  address: widget.unusedAddress,
                                  label: labelController.text,
                            );
                          }
                          await ShareWrapper.share(
                            context: context,
                            message: widget.unusedAddress, // Share only the address
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        AppLocalizations.instance
                            .translate('wallet_receive_label_hint'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppLocalizations.instance
                            .translate('wallet_receive_label_hint_privacy'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Show faucet + exchange if letterCode == 'DGB' (in our 'renderPurchaseButtons()')
            renderPurchaseButtons(),
          ],
        ),
      ],
    );
  }
}

class WalletHomeQr extends StatelessWidget {
  final String _unusedAddress;
  final String coinName;

  const WalletHomeQr(this._unusedAddress, this.coinName, {Key? key})
      : super(key: key);

  static void showQrDialog(
    BuildContext context,
    String address,
    String coinName, [
    bool hideShareButton = false,
  ]) {
    final defaultTextColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          titlePadding: const EdgeInsets.all(8),
          contentPadding: const EdgeInsets.all(8),
          children: [
            Center(
              child: Column(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.33,
                    width: MediaQuery.of(context).size.width,
                    child: Center(
                      child: Container(
                        color: Colors.white, // White behind the QR
                        child: QrImageView(
                          data: address,
                          size: 180.0,
                          embeddedImage: AssetImage(
                            AvailableCoins.getSpecificCoin(coinName).iconPath,
                          ),
                          embeddedImageStyle: const QrEmbeddedImageStyle(
                            size: Size(50, 50),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!hideShareButton)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FittedBox(
                        child: DoubleTabToClipboard(
                          withHintText: true,
                          clipBoardData: address,
                          child: SelectableText(
                            address,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: defaultTextColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!hideShareButton)
                    PeerButtonBorder(
                      action: () => ShareWrapper.share(
                        context: context,
                        message: address,
                        popNavigator: true,
                      ),
                      text: AppLocalizations.instance
                          .translate('receive_share'),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inkWell = InkWell(
      onTap: () => showQrDialog(context, _unusedAddress, coinName),
      child: QrImageView(
        data: _unusedAddress,
        size: 240.0,
        padding: const EdgeInsets.all(1),
        embeddedImage: AssetImage(
          AvailableCoins.getSpecificCoin(coinName).iconPath,
        ),
        embeddedImageStyle: const QrEmbeddedImageStyle(
          size: Size(50, 50),
        ),
      ),
    );
    return _unusedAddress.isEmpty
        ? const SizedBox(height: 240, width: 240)
        : inkWell;
  }
}
