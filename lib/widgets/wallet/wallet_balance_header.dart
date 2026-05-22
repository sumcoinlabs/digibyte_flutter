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

  String truncateDouble(double value, int decimals) {
    final mod = pow(10, decimals).toDouble();
    final truncated = (value * mod).floor() / mod;
    return truncated.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final screenWidth = MediaQuery.of(context).size.width;

    final isCompact = screenWidth < 400;
    final isVeryCompact = screenWidth < 370;

    final topGap = isVeryCompact
        ? 8.0
        : isCompact
            ? 10.0
            : 12.0;
    final connectionGap = isVeryCompact
        ? 5.0
        : isCompact
            ? 6.0
            : 8.0;
    final balanceFont = isVeryCompact
        ? 21.0
        : isCompact
            ? 23.0
            : 25.0;
    final fiatFont = isVeryCompact
        ? 13.0
        : isCompact
            ? 14.0
            : 16.0;
    final timestampFont = isVeryCompact
        ? 11.0
        : isCompact
            ? 12.0
            : 13.0;
    final rateFont = isVeryCompact
        ? 13.0
        : isCompact
            ? 14.0
            : 16.0;
    final bottomGap = isVeryCompact
        ? 36.0
        : isCompact
            ? 40.0
            : 44.0;

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

    final formattedTime = DateFormat(
      'MM/dd/yy, h:mm a',
    ).format(settings.latestTickerUpdate.toLocal());

    final hideWalletBalances = settings.hideWalletBalances;

    final coinBalanceText = hideWalletBalances
        ? '••••••••'
        : NumberFormat("#,##0.########").format(coinBalance);

    final fiatBalanceText = hideWalletBalances
        ? '•••• ${settings.selectedCurrency}'
        : '${NumberFormat("#,##0.00").format(fiatBalance)} ${settings.selectedCurrency}';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 14 : 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: topGap),
          WalletHomeConnection(_connectionState),
          SizedBox(height: connectionGap),

          // Balance row. FittedBox prevents long balances from overflowing
          // or pushing the eye icon out of alignment on smaller devices.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  coinBalanceText,
                  style: TextStyle(
                    fontSize: balanceFont,
                    color: Colors.grey[100],
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _wallet.letterCode,
                  style: TextStyle(
                    fontSize: balanceFont,
                    color: Colors.grey[100],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 9),
                Icon(
                  hideWalletBalances ? Icons.visibility_off : Icons.visibility,
                  size: isCompact ? 21 : 23,
                  color: Colors.grey[200],
                ),
              ],
            ),
          ),

          SizedBox(height: isVeryCompact ? 3 : 5),

          if (settings.selectedCurrency.isNotEmpty &&
              _wallet.letterCode != 'tDGB')
            WalletBalancePrice(
              valueInFiat: Text(
                fiatBalanceText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fiatFont,
                  color: Colors.grey[300],
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              fiatCoinValue: Text(
                '1 ${_wallet.letterCode} = ${NumberFormat("#,##0.000000").format(fiatRate)} ${settings.selectedCurrency}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: rateFont,
                  color: Colors.grey[300],
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          Padding(
            padding: EdgeInsets.only(top: isVeryCompact ? 3 : 5),
            child: Text(
              '@ $formattedTime',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: timestampFont,
                color: Colors.grey[300],
                letterSpacing: 0.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),

          if (_wallet.unconfirmedBalance > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.query_builder,
                    size: 13,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_wallet.unconfirmedBalance / decimalProduct} ${_wallet.letterCode}',
                    style: TextStyle(
                      fontSize: isCompact ? 12 : 13,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: bottomGap),
        ],
      ),
    );
  }
}
