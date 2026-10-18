import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:fast_csv/fast_csv.dart' as fast_csv;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:digibyte/exceptions/exceptions.dart';
import 'package:digibyte/models/buildresult.dart';
import 'package:digibyte/tools/validators.dart';
import 'package:digibyte/widgets/wallet/send_tab_management.dart';
import 'package:digibyte/widgets/wallet/send_tab_navigator.dart';
import 'package:provider/provider.dart';

import '/../models/available_coins.dart';
import '/../models/coin.dart';
import '/../models/hive/coin_wallet.dart';
import '/../models/hive/wallet_address.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/connection_provider.dart';
import '/../screens/wallet/wallet_home.dart';
import '/../tools/app_localizations.dart';
import '/../tools/app_routes.dart';
import '/../tools/auth.dart';
import '/../tools/utf8_text_field.dart';
import '/../widgets/buttons.dart';
import '/../widgets/service_container.dart';
import '/../widgets/wallet/wallet_balance_header.dart';
import '../../screens/wallet/transaction_confirmation.dart';
import '../../tools/logger_wrapper.dart';
import '../../tools/price_ticker.dart';

class SendTab extends StatefulWidget {
  final Function changeTab;
  final String? address;
  final String? label;
  final BackendConnectionState connectionState;
  final CoinWallet wallet;
  const SendTab({
    required this.changeTab,
    this.address,
    this.label,
    required this.wallet,
    required this.connectionState,
    super.key,
  });

  @override
  State<SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<SendTab> {
  final _formKey = GlobalKey<FormState>();
  final _addressKeyList = [GlobalKey<FormFieldState>()];
  final _amountKeyList = [GlobalKey<FormFieldState>()];
  final _labelKeyList = [GlobalKey<FormFieldState>()];
  final _opReturnKey = GlobalKey<FormFieldState>();
  final _addressControllerList = [TextEditingController()];
  final _amountControllerList = [TextEditingController()];
  final _labelControllerList = [TextEditingController()];
  final _opReturnController = TextEditingController();
  bool _initial = true;
  late Coin _availableCoin;
  late WalletProvider _walletProvider;
  late List<WalletAddress> _availableAddresses;
  bool _expertMode = false;
  bool _advancedOptionsOpen = false;
  bool _showAmountKeypad = false;
  // A fiat display rounds to cents; preserve the exact DGB value when All is used.
  bool _sendAllSelected = false;
  late AppSettingsProvider _appSettings;
  late final int _decimalProduct;
  bool _fiatEnabled = false;
  bool _fiatInputEnabled = false;
  final Map<int, String> _amountInputHelperTextList = {};
  final Map<int, double> _requestedAmountInCoinsList = {};
  double _totalAmountRequestedInCoins = 0.0;
  double _coinValue = 0.0;
  int _numberOfRecipients = 1;
  int _currentAddressIndex = 0;

  @override
  void didChangeDependencies() async {
    if (_initial) {
      _availableCoin = AvailableCoins.getSpecificCoin(widget.wallet.name);
      _walletProvider = Provider.of<WalletProvider>(context, listen: false);
      _appSettings = Provider.of<AppSettingsProvider>(context, listen: false);

      try {
        _availableAddresses = await _walletProvider.getWalletAddresses(widget.wallet.name) ?? [];
      } catch (e) {
        _availableAddresses = [];
        LoggerWrapper.logError('SendTab', 'didChangeDependencies', 'Failed to load addresses: $e');
      }
      _decimalProduct = AvailableCoins.getDecimalProduct(identifier: widget.wallet.name);
      _fiatEnabled = _appSettings.selectedCurrency.isNotEmpty && !widget.wallet.name.contains('Testnet');
      // Default to the user's configured fiat code rather than hardcoded USD.
      // The selector still lets them switch back to DGB for coin amounts.
      _fiatInputEnabled = _fiatEnabled;
      _calcAmountInputHelperText(_currentAddressIndex);

      setState(() {
        _addressControllerList[0].text = widget.address ?? '';
        _labelControllerList[0].text = widget.label ?? '';
        _initial = false;
      });
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Collapse the balance while entering an amount so the in-app keypad
        // and Send action have room above the ad/banner slot.
        if (!_showAmountKeypad)
          WalletBalanceHeader(widget.connectionState, widget.wallet, compact: true),
        const SizedBox(height: 8),
            Align(
              child: PeerContainer(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppLocalizations.instance.translate('wallet_bottom_nav_send'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 40,
                          child: Divider(
                            thickness: 3,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      if (_numberOfRecipients > 1)
                        SendTabNavigator(
                          currentIndex: _currentAddressIndex + 1,
                          numberOfRecipients: _numberOfRecipients,
                          raiseNewindex: (int newIndex) => setState(() {
                            if (triggerFormValidation()) {
                              _currentAddressIndex = newIndex - 1;
                            }
                          }),
                        ),
                      TypeAheadField<WalletAddress>(
                        hideOnEmpty: true,
                        key: _addressKeyList[_currentAddressIndex],
                        controller: _addressControllerList[_currentAddressIndex],
                        focusNode: FocusNode(),
                        builder: (context, controller, focusNode) {
                          return FormField<String>(
                            key: _addressKeyList[_currentAddressIndex],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.instance.translate('send_enter_address');
                              }
                              if (_addressControllerList.where((element) => element.text == value).length > 1) {
                                return AppLocalizations.instance.translate('send_address_already_exists');
                              }
                              var sanitized = value.trim();
                              if (validateAddress(sanitized, _availableCoin.networkType) == false) {
                                return AppLocalizations.instance.translate('send_invalid_address');
                              }
                              return null;
                            },
                            builder: (FormFieldState<String> field) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                autocorrect: false,
                                onTap: () => setState(() => _showAmountKeypad = false),
                                decoration: InputDecoration(
                                  icon: Icon(Icons.shuffle, color: Theme.of(context).primaryColor),
                                  labelText: AppLocalizations.instance.translate('tx_address'),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: AppLocalizations.instance.translate('send_paste_address'),
                                        onPressed: () async {
                                          try {
                                            final data = await Clipboard.getData('text/plain');
                                            if (data?.text != null) {
                                              _addressControllerList[_currentAddressIndex].text = data!.text!.trim();
                                              field.didChange(_addressControllerList[_currentAddressIndex].text);
                                              setState(() {});
                                            }
                                          } catch (e) {
                                            LoggerWrapper.logError('SendTab', 'paste', '$e');
                                          }
                                        },
                                        icon: Icon(Icons.paste_rounded, color: Theme.of(context).primaryColor),
                                      ),
                                      if (_appSettings.camerasAvailble)
                                        IconButton(
                                          tooltip: AppLocalizations.instance.translate('scan_qr'),
                                          onPressed: () async {
                                            setState(() => _showAmountKeypad = false);
                                            FocusScope.of(context).unfocus();
                                            final result = await Navigator.of(context).pushNamed(
                                              Routes.qrScan,
                                              arguments: AppLocalizations.instance.translate('scan_qr'),
                                            );
                                            if (!mounted) return;
                                            if (result is String && result.isNotEmpty) {
                                              _parseQrResult(result);
                                            }
                                          },
                                          icon: Icon(Icons.qr_code_scanner, color: Theme.of(context).primaryColor),
                                        ),
                                    ],
                                  ),
                                  errorText: field.errorText,
                                ),
                                onChanged: (value) => field.didChange(value),
                              );
                            },
                          );
                        },
                        suggestionsCallback: (pattern) async {
                          final suggestions = await _getSuggestions(pattern);
                          return suggestions.toList();
                        },
                        itemBuilder: (context, WalletAddress suggestion) {
                          return ListTile(
                            title: Text(suggestion.addressBookName ?? ''),
                            subtitle: Text(suggestion.address),
                          );
                        },
                        onSelected: (WalletAddress suggestion) {
                          _addressControllerList[_currentAddressIndex].text = suggestion.address;
                          _labelControllerList[_currentAddressIndex].text = suggestion.addressBookName ?? '';
                          final formFieldState = _addressKeyList[_currentAddressIndex].currentState as FormFieldState<String>?;
                          if (formFieldState != null) {
                            formFieldState.didChange(suggestion.address);
                          }
                        },
                      ),
                      TextFormField(
                        textInputAction: TextInputAction.done,
                        key: _labelKeyList[_currentAddressIndex],
                        controller: _labelControllerList[_currentAddressIndex],
                        autocorrect: false,
                        onTap: () => setState(() => _showAmountKeypad = false),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          icon: Icon(Icons.bookmark, color: Theme.of(context).primaryColor),
                          labelText: AppLocalizations.instance.translate('send_label'),
                          counterText: '',
                          suffixText: '${_labelControllerList[_currentAddressIndex].text.length}/32',
                        ),
                        maxLength: 32,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                        textInputAction: TextInputAction.done,
                        key: _amountKeyList[_currentAddressIndex],
                        controller: _amountControllerList[_currentAddressIndex],
                        autocorrect: false,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(_getValidator(_availableCoin.fractions)),
                        ],
                        readOnly: true,
                        showCursor: false,
                        enableInteractiveSelection: false,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          setState(() => _showAmountKeypad = true);
                        },
                        decoration: InputDecoration(
                          icon: Icon(Icons.money, color: Theme.of(context).primaryColor),
                          labelText: AppLocalizations.instance.translate('send_amount'),
                          suffixIcon: _fiatEnabled
                              ? PopupMenuButton<bool>(
                                  tooltip: AppLocalizations.instance.translate('send_choose_currency'),
                                  onSelected: _switchAmountCurrency,
                                  itemBuilder: (context) => [
                                    PopupMenuItem(value: false, child: Text(widget.wallet.letterCode)),
                                    PopupMenuItem(value: true, child: Text(_appSettings.selectedCurrency)),
                                  ],
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_fiatInputEnabled ? _appSettings.selectedCurrency : widget.wallet.letterCode),
                                      const Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Center(widthFactor: 1, child: Text(widget.wallet.letterCode)),
                                ),
                        ),
                        onChanged: (value) {
                          _sendAllSelected = false;
                          _calcAmountInputHelperText(_currentAddressIndex);
                          if (_amountKeyList[_currentAddressIndex].currentState?.hasError == true) {
                            _amountKeyList[_currentAddressIndex].currentState?.validate();
                          }
                        },
                        validator: (value) => _amountValidator(value!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: OutlinedButton(
                              onPressed: _numberOfRecipients == 1 ? _selectAllAmount : null,
                              child: Text(AppLocalizations.instance.translate('send_all')),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 40, top: 4, bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _amountInputHelperTextList[_currentAddressIndex] ?? '',
                            softWrap: true,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.70),
                                ),
                          ),
                        ),
                      ),
                      if (_showAmountKeypad) _buildAmountKeypad(),
                      if (!_showAmountKeypad) Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _advancedOptionsOpen = !_advancedOptionsOpen),
                          icon: Icon(_advancedOptionsOpen ? Icons.expand_less : Icons.tune),
                          label: Text(AppLocalizations.instance.translate(
                            _advancedOptionsOpen ? 'send_hide_advanced' : 'send_advanced',
                          )),
                        ),
                      ),
                      if (!_showAmountKeypad && _advancedOptionsOpen) ...[
                        SendTabAddressManagement(
                          onAdd: () {
                            if (_addNewAddress()) {
                              setState(() => _numberOfRecipients++);
                            }
                          },
                          onDelete: () => _removeAddress(_currentAddressIndex),
                          numberOfRecipients: _numberOfRecipients,
                        ),
                        if (_currentAddressIndex == 0)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _expertMode,
                            onChanged: (enabled) => setState(() {
                              _expertMode = enabled;
                              if (!enabled) _opReturnController.clear();
                            }),
                            title: Text(AppLocalizations.instance.translate('send_add_metadata')),
                          ),
                        TextButton.icon(
                          onPressed: () async => await importCsv(),
                          icon: const Icon(Icons.file_upload_outlined),
                          label: Text(AppLocalizations.instance.translate('send_import_csv')),
                        ),
                      ],
                      if (!_showAmountKeypad && _expertMode)
                        TextFormField(
                          textInputAction: TextInputAction.done,
                          key: _opReturnKey,
                          controller: _opReturnController,
                          autocorrect: false,
                          maxLength: _availableCoin.opreturnSize,
                          minLines: 1,
                          maxLines: 5,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                            var utf8Length = utf8.encode(_opReturnController.text).length;
                            return Text('$utf8Length/$maxLength', style: Theme.of(context).textTheme.bodySmall);
                          },
                          inputFormatters: [
                            Utf8LengthLimitingTextInputFormatter(_availableCoin.opreturnSize),
                          ],
                          decoration: InputDecoration(
                            suffixIcon: IconButton(
                              onPressed: () async {
                                print('Paste button pressed (OP_RETURN)');
                                try {
                                  var data = await Clipboard.getData('text/plain');
                                  if (data?.text != null) {
                                    _opReturnController.text = data!.text!.trim();
                                  } else {
                                    print('No clipboard data available');
                                  }
                                } catch (e) {
                                  print('Clipboard error: $e');
                                }
                              },
                              icon: Icon(Icons.paste_rounded, color: Theme.of(context).primaryColor),
                            ),
                            icon: Icon(Icons.message, color: Theme.of(context).primaryColor),
                            labelText: AppLocalizations.instance.translate('send_op_return'),
                          ),
                        ),
                      if (!_showAmountKeypad && _expertMode)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            AppLocalizations.instance.translate('wallet_send_label_hint_metadata'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.secondary),
                          ),
                        ),
                      if (!_showAmountKeypad) ...[
                        const SizedBox(height: 24),
                        PeerButton(
                        text: AppLocalizations.instance.translate('send'),
                        action: () async {
                          if (triggerFormValidation()) {
                            _formKey.currentState!.save();
                            setState(() => _showAmountKeypad = false);
                            FocusScope.of(context).unfocus(); // Hide keyboard
                            _amountControllerList.asMap().forEach((index, _) => _calcAmountInputHelperText(index));
                            if (_appSettings.authenticationOptions!['sendTransaction']!) {
                              await Auth.requireAuth(
                                context: context,
                                biometricsAllowed: _appSettings.biometricsAllowed,
                                callback: () => _showTransactionConfirmation(context),
                              );
                            } else {
                              _showTransactionConfirmation(context);
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppLocalizations.instance.translate('send_errors_solve'))),
                            );
                          }
                        },
                      ),
                        const SizedBox(height: 24), // Breathing room above the ad slot.
                      ],
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }

  bool triggerFormValidation() => _formKey.currentState!.validate();

  bool _addNewAddress({String address = '', double amount = 0.0, String label = '', bool fromImport = false}) {
    if (triggerFormValidation() || fromImport) {
      _labelControllerList.add(TextEditingController(text: label));
      _addressControllerList.add(TextEditingController(text: address));
      _amountControllerList.add(TextEditingController(text: amount.toString()));
      _labelKeyList.add(GlobalKey<FormFieldState>());
      _addressKeyList.add(GlobalKey<FormFieldState>());
      _amountKeyList.add(GlobalKey<FormFieldState>());
      _amountInputHelperTextList[_numberOfRecipients] = '';
      _requestedAmountInCoinsList[_numberOfRecipients] = amount;
      if (!fromImport) {
        _formKey.currentState!.save();
        setState(() => _currentAddressIndex = _numberOfRecipients);
      }
      return true;
    }
    return false;
  }

  String? _amountValidator(String value) {
    if (value.trim().isEmpty) return AppLocalizations.instance.translate('send_enter_amount');
    final inputValue = double.tryParse(value.replaceAll(',', '.'));
    if (inputValue == null || !inputValue.isFinite || inputValue <= 0) {
      return AppLocalizations.instance.translate('send_enter_amount');
    }
    final sanitizedValue = (_requestedAmountInCoinsList[_currentAddressIndex] ?? 0).toString();
    _buildRecipientMap();

    var txValueInSatoshis = double.parse((_totalAmountRequestedInCoins * _decimalProduct).toStringAsFixed(_availableCoin.fractions));
    LoggerWrapper.logInfo('SendTab', 'send_amount', 'req value $txValueInSatoshis - wallet balance ${widget.wallet.balance}');
    if (sanitizedValue.contains('.') && sanitizedValue.split('.')[1].length > _availableCoin.fractions) {
      return AppLocalizations.instance.translate('send_amount_small');
    }
    if (txValueInSatoshis > widget.wallet.balance || (txValueInSatoshis == 0 && widget.wallet.balance == 0)) {
      return AppLocalizations.instance.translate('send_amount_exceeds');
    }
    if (txValueInSatoshis < _availableCoin.minimumTxValue && _opReturnController.text.isEmpty) {
      return AppLocalizations.instance.translate('send_amount_below_minimum', {'amount': '${_availableCoin.minimumTxValue / _decimalProduct}'});
    }
    if (txValueInSatoshis == widget.wallet.balance && widget.wallet.balance == _availableCoin.minimumTxValue) {
      return AppLocalizations.instance.translate('send_amount_below_minimum_unable', {'amount': '${_availableCoin.minimumTxValue / _decimalProduct}'});
    }
    return null;
  }

  Map<String, int> _buildRecipientMap() {
    Map<String, int> recipients = {};
    double totalCoins = 0;
    _amountControllerList.asMap().forEach((key, value) {
      var coins = Decimal.parse(_formatAmount(
        _requestedAmountInCoinsList[key] ?? 0.0,
        _availableCoin.fractions,
      ));
      var decimalProduct = Decimal.parse(_decimalProduct.toString());
      recipients[_addressControllerList[key].text.trim()] = int.parse((coins * decimalProduct).toString());
      totalCoins += coins.toDouble();
    });
    _totalAmountRequestedInCoins = totalCoins;
    return recipients;
  }

  Future<BuildResult?> _buildTx() async {
    try {
      return await _walletProvider.buildTransaction(
        identifier: widget.wallet.name,
        recipients: _buildRecipientMap(),
        fee: 0,
        opReturn: _opReturnKey.currentState?.value ?? '',
      );
    } catch (e) {
      LoggerWrapper.logError('SendTab', 'buildTx', 'error building tx: ${e.toString()}');
      if (e.runtimeType == CantPayForFeesException) {
        final exception = e as CantPayForFeesException;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.instance.translate('send_errors_cant_pay_fees', {
              'feesMissing': (exception.feesMissing / _decimalProduct).toString(),
              'letter_code': widget.wallet.letterCode,
            })),
            duration: const Duration(seconds: 7),
          ),
        );
      }
      return null;
    }
  }

  String _formatAmount(double value, int decimals) {
    if (!value.isFinite) return '0';
    final fixed = value.toStringAsFixed(decimals);
    if (!fixed.contains('.')) return fixed;
    return fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  double _currentFiatRate() => PriceTicker.renderPrice(
        1,
        _appSettings.selectedCurrency,
        widget.wallet.letterCode,
        _appSettings.exchangeRates,
      );

  void _switchAmountCurrency(bool fiat) {
    if (fiat == _fiatInputEnabled) return;
    final rate = _currentFiatRate();
    if (fiat && (!rate.isFinite || rate <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exchange rate unavailable. Try again shortly.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final coinAmounts = List<double>.generate(_amountControllerList.length, (index) {
      if (_sendAllSelected && index == 0) {
        return widget.wallet.balance / _decimalProduct;
      }
      return _requestedAmountInCoinsList[index] ?? 0.0;
    });
    setState(() {
      _fiatInputEnabled = fiat;
      for (var index = 0; index < _amountControllerList.length; index++) {
        if (_amountControllerList[index].text.trim().isEmpty) continue;
        final coins = coinAmounts[index];
        final displayed = fiat ? coins * rate : coins;
        _amountControllerList[index].text = _formatAmount(
          displayed,
          fiat ? 2 : _availableCoin.fractions,
        );
        _requestedAmountInCoinsList[index] = coins;
      }
    });
    for (var index = 0; index < _amountControllerList.length; index++) {
      _calcAmountInputHelperText(index);
    }
  }

  void _selectAllAmount() {
    if (_numberOfRecipients != 1) return;
    final coins = widget.wallet.balance / _decimalProduct;
    final rate = _currentFiatRate();
    if (_fiatInputEnabled && (!rate.isFinite || rate <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exchange rate unavailable. Try again shortly.')),
      );
      return;
    }
    setState(() {
      _sendAllSelected = true;
      _amountControllerList[0].text = _formatAmount(
        _fiatInputEnabled ? coins * rate : coins,
        _fiatInputEnabled ? 2 : _availableCoin.fractions,
      );
    });
    _calcAmountInputHelperText(0);
    if (_amountKeyList[0].currentState?.hasError == true) {
      _amountKeyList[0].currentState?.validate();
    }
  }

  void _pressAmountKey(String key) {
    final index = _currentAddressIndex;
    final controller = _amountControllerList[index];
    final original = controller.text;
    var next = original;
    if (key == 'backspace') {
      if (next.isNotEmpty) next = next.substring(0, next.length - 1);
    } else if (key == '.') {
      if (next.contains('.')) return;
      next = next.isEmpty ? '0.' : '$next.';
    } else {
      if (next == '0') {
        next = key == '0' ? '0' : key;
      } else {
        if (!next.contains('.') && next.length >= 18) return;
        if (next.contains('.')) {
          final decimals = next.split('.').last.length;
          if (decimals >= (_fiatInputEnabled ? 2 : _availableCoin.fractions)) return;
        }
        next += key;
      }
    }
    _sendAllSelected = false;
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _calcAmountInputHelperText(index);
    if (_amountKeyList[index].currentState?.hasError == true) {
      _amountKeyList[index].currentState?.validate();
    }
  }

  Widget _buildAmountKeypad() {
    const keys = <List<String>>[
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', 'backspace'],
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Enter amount', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              TextButton.icon(
                onPressed: () => setState(() => _showAmountKeypad = false),
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final row in keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Center(
                          child: Material(
                            color: Colors.transparent,
                            shape: CircleBorder(
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.55),
                                width: 0.85,
                              ),
                            ),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _pressAmountKey(key),
                              child: SizedBox(
                                width: 54,
                                height: 54,
                                child: Center(
                                  child: key == 'backspace'
                                      ? const Icon(
                                          Icons.backspace_outlined,
                                          color: Colors.white,
                                          size: 22,
                                        )
                                      : Text(
                                          key,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _calcAmountInputHelperText(int index) {
    final text = _amountControllerList[index].text.trim().replaceAll(',', '.');
    final amount = double.tryParse(text) ?? 0.0;
    final rate = _fiatEnabled ? _currentFiatRate() : 0.0;
    final validRate = rate.isFinite && rate > 0;
    final rawCoins = _sendAllSelected && index == 0
        ? widget.wallet.balance / _decimalProduct
        : (_fiatInputEnabled ? (validRate ? amount / rate : 0.0) : amount);
    // Match on-chain precision before the recipient map converts to atomic units.
    final coins = rawCoins.isFinite
        ? double.parse(rawCoins.toStringAsFixed(_availableCoin.fractions))
        : 0.0;
    final coinText = _formatAmount(coins, _availableCoin.fractions);
    final rateText = _formatAmount(rate, 8);
    final currency = _appSettings.selectedCurrency;
    final coinCode = widget.wallet.letterCode;
    String helper = '';
    if (_fiatEnabled) {
      if (!validRate) {
        helper = 'Exchange rate unavailable';
      } else if (text.isEmpty) {
        helper = '1 $coinCode = $rateText $currency';
      } else if (_fiatInputEnabled) {
        helper = '$coinText $coinCode ≈ ${_formatAmount(amount, 2)} $currency';
      } else {
        final fiatValue = coins * rate;
        final fiatText = _formatAmount(fiatValue, fiatValue.abs() < 0.01 ? 8 : 2);
        helper = '$coinText $coinCode ≈ $fiatText $currency';
      }
    }
    _coinValue = validRate ? rate : 0.0;
    _requestedAmountInCoinsList[index] = coins;
    _amountInputHelperTextList[index] = helper;
    if (mounted) setState(() {});
  }

  Future<List<WalletAddress>> _getSuggestions(String pattern) async {
    return _availableAddresses.where((element) =>
        !element.isOurs && (element.address.contains(pattern) || element.addressBookName?.contains(pattern) == true)).toList();
  }

  RegExp _getValidator(int fractions) {
    var expression = r'^([1-9]{1}[0-9]{0,' +
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

  void _parseQrResult(String code) {
    try {
      var parsed = Uri.parse(code);
      if (parsed.path.isNotEmpty) {
        _addressControllerList[_currentAddressIndex].text = parsed.path.trim();
      } else {
        // If path is empty, use the full code as a fallback (e.g., for simple address QR codes)
        _addressControllerList[_currentAddressIndex].text = code.trim();
      }
      parsed.queryParameters.forEach((key, value) {
        if (key == 'amount') {
          _sendAllSelected = false;
          final qrCoins = double.tryParse(value.replaceAll(',', '.'));
          if (qrCoins != null && qrCoins.isFinite && qrCoins >= 0) {
            // URI amounts represent exact DGB, not fiat. Keep their full coin
            // precision rather than converting through rounded fiat cents.
            _fiatInputEnabled = false;
            _amountControllerList[_currentAddressIndex].text =
                _formatAmount(qrCoins, _availableCoin.fractions);
            _calcAmountInputHelperText(_currentAddressIndex);
          }
        }
        else if (key == 'label') _labelControllerList[_currentAddressIndex].text = value;
      });
      final formFieldState = _addressKeyList[_currentAddressIndex].currentState as FormFieldState<String>?;
      if (formFieldState != null) {
        formFieldState.didChange(_addressControllerList[_currentAddressIndex].text);
      }
      setState(() {}); // Ensure UI updates
      // A scanned address should not mark the untouched amount as invalid.
      (_addressKeyList[_currentAddressIndex].currentState as FormFieldState<String>?)?.validate();
    } catch (e) {
      print('QR Parse Error: $e');
      // Fallback to using the raw code if URI parsing fails
      _addressControllerList[_currentAddressIndex].text = code.trim();
      final formFieldState = _addressKeyList[_currentAddressIndex].currentState as FormFieldState<String>?;
      if (formFieldState != null) {
        formFieldState.didChange(_addressControllerList[_currentAddressIndex].text);
      }
      setState(() {});
      (_addressKeyList[_currentAddressIndex].currentState as FormFieldState<String>?)?.validate();
    }
  }

  void _removeAddress(int index) {
    _labelControllerList.removeAt(index);
    _addressControllerList.removeAt(index);
    _amountControllerList.removeAt(index);
    _labelKeyList.removeAt(index);
    _addressKeyList.removeAt(index);
    _amountKeyList.removeAt(index);
    _amountInputHelperTextList.remove(index);
    _requestedAmountInCoinsList.remove(index);
    setState(() {
      _numberOfRecipients--;
      _currentAddressIndex = _currentAddressIndex > 0 ? _currentAddressIndex - 1 : 0;
    });
  }

  void _showTransactionConfirmation(BuildContext context) async {
    var buildResult = await _buildTx();
    if (buildResult != null) {
      await Navigator.of(context).pushNamed(
        Routes.transactionConfirmation,
        arguments: TransactionConfirmationArguments(
          buildResult: buildResult,
          decimalProduct: _decimalProduct,
          coinLetterCode: widget.wallet.letterCode,
          coinIdentifier: widget.wallet.name,
          callBackAfterSend: () => widget.changeTab(WalletTab.transactions),
          fiatPricePerCoin: _coinValue,
          fiatCode: _appSettings.selectedCurrency,
        ),
      );
      _labelControllerList.asMap().forEach((index, controller) {
        if (controller.text.isNotEmpty) {
          _walletProvider.updateOrCreateAddressLabel(
            identifier: widget.wallet.name,
            address: _addressControllerList[index].text,
            label: controller.text,
          );
        }
      });
    }
  }

  Future<void> importCsv() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      String csv = kIsWeb
          ? String.fromCharCodes(result.files.single.bytes!)
          : await File(result.files.single.path!).readAsString();
      final parsed = fast_csv.parse(csv);
      int i = 0;
      for (final row in parsed) {
        final address = row[0];
        final amount = double.parse(row[1].replaceAll(',', '.'));
        if (i == 0) {
          _addressControllerList[0].text = address;
          _sendAllSelected = false;
          _amountControllerList[0].text = amount.toString();
          _calcAmountInputHelperText(0);
        } else {
          _addNewAddress(address: address, amount: amount, label: '', fromImport: true);
          setState(() => _numberOfRecipients++);
        }
        i++;
      }
    }
  }
}
