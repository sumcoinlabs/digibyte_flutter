import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:digibyte/providers/connection_provider.dart';
import 'package:digibyte/providers/app_settings_provider.dart';
import 'package:digibyte/widgets/double_tab_to_clipboard.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../widgets/banner_ad_widget.dart';
import '../../widgets/native_ad_widget.dart';

import '../../models/available_coins.dart';
import '../../models/hive/coin_wallet.dart';
import '../../models/hive/wallet_transaction.dart';
import '../../tools/app_localizations.dart';
import '../../tools/price_ticker.dart';
import '../../widgets/buttons.dart';
import '../../widgets/service_container.dart';

class TransactionDetails extends StatelessWidget {
  const TransactionDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final WalletTransaction tx = args['tx'];
    final CoinWallet coinWallet = args['wallet'];
    final baseUrl =
        '${AvailableCoins.getSpecificCoin(coinWallet.name).explorerUrl}';
    final decimalProduct = AvailableCoins.getDecimalProduct(
      identifier: coinWallet.name,
    );
    final appSettings = context.watch<AppSettingsProvider>();
    final currentFiatRate = PriceTicker.renderPrice(
      1,
      tx.fiatCodeAtTx.isNotEmpty
          ? tx.fiatCodeAtTx
          : appSettings.selectedCurrency,
      coinWallet.letterCode,
      appSettings.exchangeRates,
    );
    final txCoinValue = tx.value / decimalProduct;
    final fiatValueAtTx = tx.fiatRateAtTx * txCoinValue;
    final currentFiatValue = currentFiatRate * txCoinValue;
    final percentChange = tx.fiatRateAtTx > 0
        ? ((currentFiatRate - tx.fiatRateAtTx) / tx.fiatRateAtTx) * 100
        : 0.0;
    final snapshotLabel =
        tx.direction == 'out' ? 'Rate when sent' : 'Rate when received';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          AppLocalizations.instance.translate('transaction_details'),
        ),
      ),
      body: Align(
        child: PeerContainer(
          noSpacers: true,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.instance.translate('id'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(tx.txid),
                ],
              ),
              const Divider(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.instance.translate('time'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(
                    tx.timestamp != 0
                        ? DateFormat().format(
                            DateTime.fromMillisecondsSinceEpoch(
                              tx.timestamp * 1000,
                            ),
                          )
                        : AppLocalizations.instance.translate('unconfirmed'),
                  ),
                ],
              ),
              const Divider(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.instance.translate('tx_value'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(
                    '${tx.value / decimalProduct} ${coinWallet.letterCode}',
                  ),
                ],
              ),
              tx.direction == 'out'
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Text(
                          AppLocalizations.instance.translate('tx_fee'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SelectableText(
                          '${tx.fee / decimalProduct} ${coinWallet.letterCode}',
                        ),
                      ],
                    )
                  : Container(),
              if (tx.fiatRateAtTx > 0) ...[
                const Divider(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historical Value',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    renderDetailRow(
                      context,
                      'Starting balance',
                      '${NumberFormat("#,##0.########").format(tx.startingBalance / decimalProduct)} ${coinWallet.letterCode}',
                    ),
                    renderDetailRow(
                      context,
                      'Ending balance',
                      '${NumberFormat("#,##0.########").format(tx.endingBalance / decimalProduct)} ${coinWallet.letterCode}',
                    ),
                    renderDetailRow(
                      context,
                      snapshotLabel,
                      '1 ${coinWallet.letterCode} = ${NumberFormat("#,##0.000000").format(tx.fiatRateAtTx)} ${tx.fiatCodeAtTx}',
                    ),
                    renderDetailRow(
                      context,
                      'Value then',
                      '${NumberFormat("#,##0.00######").format(fiatValueAtTx)} ${tx.fiatCodeAtTx}',
                    ),
                    if (currentFiatRate > 0)
                      renderDetailRow(
                        context,
                        'Current value',
                        '${NumberFormat("#,##0.00######").format(currentFiatValue)} ${tx.fiatCodeAtTx}',
                      ),
                    if (currentFiatRate > 0)
                      renderDetailRow(
                        context,
                        'Change since then',
                        '${percentChange >= 0 ? "+" : ""}${NumberFormat("#,##0.00").format(percentChange)}%',
                        valueColor: percentChange > 0
                            ? const Color(0xFF2EAD4F)
                            : percentChange < 0
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.secondary,
                      ),
                  ],
                ),
              ],
              const Divider(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.instance.translate('tx_recipients'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...renderRecipients(
                    tx: tx,
                    letterCode: coinWallet.letterCode,
                    decimalProduct: decimalProduct,
                  ),
                ],
              ),
              const Divider(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.instance.translate('tx_direction'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(tx.direction),
                ],
              ),
              const Divider(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.instance.translate('tx_confirmations'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SelectableText(
                    tx.confirmations == -1
                        ? AppLocalizations.instance.translate('tx_rejected')
                        : tx.confirmations == 0
                            ? AppLocalizations.instance.translate('unconfirmed')
                            : '${NumberFormat("#,##0").format(tx.confirmations)} confirmation${tx.confirmations == 1 ? "" : "s"}',
                  ),
                ],
              ),
              tx.opReturn.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Text(
                          AppLocalizations.instance.translate(
                            'send_op_return',
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SelectableText(tx.opReturn),
                      ],
                    )
                  : const SizedBox(),
              tx.confirmations == -1
                  ? ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        AppLocalizations.instance.translate('tx_show_hex'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      children: [
                        DoubleTabToClipboard(
                          clipBoardData: tx.broadcastHex,
                          withHintText: true,
                          child: SelectableText(
                            tx.broadcastHex,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(),
              const SizedBox(height: 20),
              tx.confirmations == -1
                  ? Center(
                      child: PeerButton(
                        action: () {
                          Provider.of<ConnectionProvider>(
                            context,
                            listen: false,
                          ).broadcastTransaction(
                            tx.broadcastHex,
                            tx.txid,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.instance.translate(
                                  'tx_retry_snack',
                                ),
                                textAlign: TextAlign.center,
                              ),
                              duration: const Duration(seconds: 5),
                            ),
                          );
                          Navigator.of(context).pop();
                        },
                        text: AppLocalizations.instance.translate(
                          'tx_retry_broadcast',
                        ),
                      ),
                    )
                  : Center(
                      child: PeerButton(
                        action: () => _launchURL(baseUrl + tx.txid + '.htm'),
                        text: AppLocalizations.instance.translate(
                          'tx_view_in_explorer',
                        ),
                      ),
                    ),
              // Add some space
              const SizedBox(height: 25),
              // Add the banner ad widget here.
              BannerAdWidget(),
              // Add the native ad widget here.
              //const SizedBox(height: 25),
              //NativeAdWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget renderDetailRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> renderRecipients({
    required WalletTransaction tx,
    required String letterCode,
    required int decimalProduct,
  }) {
    List<Widget> list = [];

    if (tx.recipients.isEmpty) {
      list.add(
        renderRow(tx.address, tx.value / decimalProduct, letterCode),
      );
    }
    tx.recipients.forEach(
      (addr, value) => list.add(
        renderRow(addr, value / decimalProduct, letterCode),
      ),
    );
    return list;
  }

  Widget renderRow(String addr, double value, String letterCode) {
    return Row(
      key: Key(addr),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          flex: 2,
          child: DoubleTabToClipboard(
            clipBoardData: addr,
            withHintText: false,
            child: Text(
              addr,
              style: const TextStyle(
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Flexible(
          child: Text('$value $letterCode'),
        ),
      ],
    );
  }

  void _launchURL(String url) async {
    await canLaunchUrlString(url)
        ? await launchUrlString(
            url,
          )
        : throw 'Could not launch $url';
  }
}
