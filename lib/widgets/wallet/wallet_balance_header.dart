import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
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
    double mod = pow(10, decimals).toDouble();
    double truncated = (value * mod).floor() / mod;
    // This ensures we always show exactly `decimals` decimal places
    return truncated.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    var settings = context.watch<AppSettingsProvider>();
    final decimalProduct = AvailableCoins.getDecimalProduct(
      identifier: _wallet.name,
    );

    double coinBalance = _wallet.balance / decimalProduct;

    // Render the fiat price for the entire balance
    double fiatBalance = PriceTicker.renderPrice(
      coinBalance,
      settings.selectedCurrency,
      _wallet.letterCode,
      settings.exchangeRates,
    );

    // Render the fiat rate for a single coin
    double fiatRate = PriceTicker.renderPrice(
      1,
      settings.selectedCurrency,
      _wallet.letterCode,
      settings.exchangeRates,
    );

    DateTime? lastUpdate = settings.latestTickerUpdate;
    String? formattedTime;
    if (lastUpdate != null) {
      formattedTime =
          DateFormat('MM/dd/yy, h:mm a').format(lastUpdate.toLocal());
    }

    return Column(
      children: [
        const SizedBox(height: 28),
        WalletHomeConnection(_connectionState),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Coin balance and symbol
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${NumberFormat("#,##0.########").format(coinBalance)}',
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
                  ],
                ),
                const SizedBox(height: 8),
                // Fiat values if applicable
                if (settings.selectedCurrency.isNotEmpty &&
                    _wallet.letterCode != 'tDGB')
                  WalletBalancePrice(
                    valueInFiat: Text(
                      '${NumberFormat("#,##0.00").format(fiatBalance)} ${settings.selectedCurrency}',
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

                // Last updated time (if available)
                if (formattedTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      children: [
                        Text(
                          '@ $formattedTime',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[300],
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w400,
                          ),
                        ),

                        SizedBox(height: 16), // Adds space below the text
                      ],
                    ),
                  ),
                // Unconfirmed balance display if any
                if (_wallet.unconfirmedBalance > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
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
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
