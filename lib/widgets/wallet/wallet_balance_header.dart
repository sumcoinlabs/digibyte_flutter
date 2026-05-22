import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/available_coins.dart';
import '../../models/hive/coin_wallet.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/connection_provider.dart';
import '../../tools/price_ticker.dart';
import 'wallet_home/wallet_home_connection.dart';
import 'wallet_balance_price.dart';

class WalletBalanceHeader extends StatelessWidget {
  final BackendConnectionState _connectionState;
  final CoinWallet _wallet;

  const WalletBalanceHeader(
    this._connectionState,
    this._wallet, {
    super.key,
  });

  /// Truncates [value] to [decimals] decimal places without rounding.
  String truncateDouble(double value, int decimals) {
    final mod = pow(10, decimals).toDouble();
    final truncated = (value * mod).floor() / mod;
    return truncated.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final decimalProduct = AvailableCoins.getDecimalProduct(
      identifier: _wallet.name,
    );

    final coinBalance = _wallet.balance / decimalProduct;

    final fiatBalance = PriceTicker.renderPrice(
      coinBalance,
      settings.selectedCurrency,
      _wallet.letterCode,
      settings.exchangeRates,
    );

    final fiatRate = PriceTicker.renderPrice(
      1,
      settings.selectedCurrency,
      _wallet.letterCode,
      settings.exchangeRates,
    );

    final lastUpdate = settings.latestTickerUpdate;
    final formattedTime = DateFormat(
      'MM/dd/yy, h:mm a',
    ).format(lastUpdate.toLocal());

    final hideWalletBalances = settings.hideWalletBalances;

    final coinBalanceText = hideWalletBalances
        ? '••••••••'
        : NumberFormat("#,##0.########").format(coinBalance);

    final fiatBalanceText = hideWalletBalances
        ? '•••• ${settings.selectedCurrency}'
        : '${NumberFormat("#,##0.00").format(fiatBalance)} ${settings.selectedCurrency}';

    return Column(
      children: [
        const SizedBox(height: 28),
        WalletHomeConnection(_connectionState),
        const SizedBox(height: 18),

        // Main balance row. The actual tap target is handled above this
        // widget in TransactionList because that screen uses a Stack layout.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              coinBalanceText,
              style: TextStyle(
                fontSize: 25,
                color: Colors.grey[100],
                letterSpacing: 1.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _wallet.letterCode,
              style: TextStyle(
                fontSize: 25,
                color: Colors.grey[100],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              hideWalletBalances ? Icons.visibility_off : Icons.visibility,
              size: 23,
              color: Colors.grey[200],
            ),
          ],
        ),

        const SizedBox(height: 8),

        if (settings.selectedCurrency.isNotEmpty &&
            _wallet.letterCode != 'tDGB')
          WalletBalancePrice(
            valueInFiat: Text(
              fiatBalanceText,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[300],
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            fiatCoinValue: Text(
              '1 ${_wallet.letterCode} = ${NumberFormat("#,##0.000000").format(fiatRate)} ${settings.selectedCurrency}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[300],
                letterSpacing: 1.09,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            '@ $formattedTime',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[300],
              letterSpacing: 1.0,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),

        if (_wallet.unconfirmedBalance > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.query_builder,
                  size: 14,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  '${_wallet.unconfirmedBalance / decimalProduct} ${_wallet.letterCode}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),
      ],
    );
  }
}
