import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';
import 'package:provider/provider.dart';

import '../../models/available_coins.dart';
import '../../models/hive/coin_wallet.dart';
import '../../providers/connection_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/wallet_provider.dart';
import '/../tools/app_localizations.dart';
import '/../models/hive/wallet_transaction.dart';
import '/../tools/app_routes.dart';
import '/../widgets/wallet/wallet_balance_header.dart';
import '/../widgets/service_container.dart';

class TransactionList extends StatefulWidget {
  final List<WalletTransaction> walletTransactions;
  final CoinWallet wallet;
  final BackendConnectionState connectionState;

  const TransactionList({
    required this.walletTransactions,
    required this.wallet,
    required this.connectionState,
    super.key,
  });

  @override
  State<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  String _filterChoice = 'all';
  late final int _decimalProduct;
  late final NumberFormat _numberFormat;

  void _handleSelect(String newChoice) {
    setState(() {
      _filterChoice = newChoice;
    });
  }

  @override
  void initState() {
    _decimalProduct = AvailableCoins.getDecimalProduct(
      identifier: widget.wallet.name,
    );
    _numberFormat = NumberFormat("#,##0.000000", "en_US");
    super.initState();
  }

  String resolveAddressDisplayName(String address) {
    final result = context.read<WalletProvider>().getLabelForAddress(
          widget.wallet.name,
          address,
        );
    if (result != '') return result;
    return address;
  }

  Widget renderConfirmationIndicator(WalletTransaction tx) {
    if (tx.confirmations == -1) {
      return const Text(
        'X',
        textScaler: TextScaler.linear(0.9),
        style: TextStyle(color: Colors.red),
      );
    }
    return tx.broadCasted == false
        ? Text(
            '?',
            textScaler: const TextScaler.linear(0.9),
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
            ),
          )
        : CircularStepProgressIndicator(
            selectedStepSize: 5,
            unselectedStepSize: 5,
            totalSteps: 6,
            currentStep: tx.confirmations.clamp(0, 6).toInt(),
            width: 20,
            height: 20,
            selectedColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2057A8)
                : Theme.of(context).primaryColor,
            unselectedColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Theme.of(context).unselectedWidgetColor.withOpacity(0.5),
            stepSize: 4,
            roundedCap: (_, __) => true,
          );
  }

  @override
  Widget build(BuildContext context) {
    var reversedTx = widget.walletTransactions
        .where(
          (element) => element.timestamp != -1,
        ) // Filter "phantom" tx
        .toList()
        .reversed
        .toList();
    var filteredTx = reversedTx;
    if (_filterChoice != 'all') {
      filteredTx = reversedTx
          .where(
            (element) => element.direction == _filterChoice,
          )
          .toList();
    }

    return Stack(
      children: [
        // Wallet Balance Header at the top
        WalletBalanceHeader(
          widget.connectionState,
          widget.wallet,
        ),

        // Main content
        widget.walletTransactions
                .where((element) =>
                    element.timestamp !=
                    -1) // Filter out "phantom" transactions
                .isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height / 8,
                  ),
                  Image.asset(
                    'assets/img/list-empty.png',
                    height: MediaQuery.of(context).size.height / 4,
                  ),
                  Center(
                    child: Text(
                      AppLocalizations.instance.translate('transactions_none'),
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
                ],
              )
            : Align(
                child: PeerContainer(
                  isTransparent: true,
                  noSpacers: true,
                  child: GestureDetector(
                    onHorizontalDragEnd: (dragEndDetails) {
                      if (dragEndDetails.primaryVelocity! < 0) {
                        // Left swipe
                        if (_filterChoice == 'in') {
                          _handleSelect('all');
                        } else if (_filterChoice == 'all') {
                          _handleSelect('out');
                        }
                      } else if (dragEndDetails.primaryVelocity! > 0) {
                        // Right swipe
                        if (_filterChoice == 'out') {
                          _handleSelect('all');
                        } else if (_filterChoice == 'all') {
                          _handleSelect('in');
                        }
                      }
                    },
                    child: ListView.builder(
                      itemCount: filteredTx.length + 1,
                      itemBuilder: (_, i) {
                        if (i > 0) {
                          return Container(
                            color: Theme.of(context).primaryColor,
                            child: Card(
                              elevation: 0,
                              child: ListTile(
                                horizontalTitleGap: 16,
                                onTap: () => Navigator.of(context).pushNamed(
                                  Routes.transaction,
                                  arguments: {
                                    'tx': filteredTx[i - 1],
                                    'wallet': widget.wallet,
                                  },
                                ),
                                leading: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 500),
                                      child: renderConfirmationIndicator(
                                        filteredTx[i - 1],
                                      ),
                                    ),
                                    Text(
                                      DateFormat('d. MMM').format(
                                        filteredTx[i - 1].timestamp != 0
                                            ? DateTime
                                                .fromMillisecondsSinceEpoch(
                                                filteredTx[i - 1].timestamp *
                                                    1000,
                                              )
                                            : DateTime.now(),
                                      ),
                                      style: TextStyle(
                                        fontWeight:
                                            filteredTx[i - 1].timestamp != 0
                                                ? FontWeight.w500
                                                : FontWeight.w300,
                                      ),
                                      textScaler: const TextScaler.linear(0.8),
                                    ),
                                  ],
                                ),
                                title: Center(
                                  child: Text(
                                    filteredTx[i - 1].txid,
                                    overflow: TextOverflow.ellipsis,
                                    textScaler: const TextScaler.linear(0.9),
                                    style: TextStyle(
                                      color:
                                          filteredTx[i - 1].direction == 'out'
                                              ? Colors.red
                                              : Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFF38C172)
                                                  : const Color(0xFF38C172),
                                    ),
                                  ),
                                ),
                                subtitle: Center(
                                  child: Text(
                                    resolveAddressDisplayName(
                                      filteredTx[i - 1].address,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    textScaler: const TextScaler.linear(1),
                                    style: TextStyle(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      (filteredTx[i - 1].direction == 'in'
                                              ? '+'
                                              : '-') +
                                          _numberFormat.format(
                                              filteredTx[i - 1].value /
                                                  _decimalProduct),
                                      style: TextStyle(
                                        fontWeight:
                                            filteredTx[i - 1].timestamp != 0
                                                ? FontWeight.bold
                                                : FontWeight.w300,
                                        color: filteredTx[i - 1].direction ==
                                                'in'
                                            ? Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? const Color(0xFF38C172)
                                                : const Color(0xFF38C172)
                                            : Colors.red,
                                        fontSize: 16,
                                      ),
                                    ),
                                    filteredTx[i - 1].direction == 'out'
                                        ? Text(
                                            '-${_numberFormat.format(filteredTx[i - 1].fee / _decimalProduct)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w300,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                              fontSize: 12,
                                            ),
                                          )
                                        : const SizedBox(
                                            height: 0,
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        } else if (i == 0 &&
                            widget.walletTransactions.isNotEmpty) {
                          return Column(
                            children: [
                              SizedBox(
                                height: widget.wallet.unconfirmedBalance > 0
                                    ? 125
                                    : 110,
                              ),
                              // Add spacing between the WalletBalanceHeader and the filter buttons
                              SizedBox(
                                height: 60, // Space between balance and filters
                              ),
                              // Add filter buttons
                              Container(
                                color: Theme.of(context).primaryColor,
                                width: MediaQuery.of(context).size.width,
                                child: Center(
                                  child: Wrap(
                                    spacing: 8.0,
                                    children: <Widget>[
                                      ChoiceChip(
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                        selectedColor:
                                            Theme.of(context).shadowColor,
                                        label: Text(
                                          AppLocalizations.instance
                                              .translate('transactions_in'),
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                          ),
                                        ),
                                        selected: _filterChoice == 'in',
                                        onSelected: (_) => _handleSelect('in'),
                                      ),
                                      ChoiceChip(
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                        selectedColor:
                                            Theme.of(context).shadowColor,
                                        label: Text(
                                          AppLocalizations.instance
                                              .translate('transactions_all'),
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                          ),
                                        ),
                                        selected: _filterChoice == 'all',
                                        onSelected: (_) => _handleSelect('all'),
                                      ),
                                      ChoiceChip(
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                        selectedColor:
                                            Theme.of(context).shadowColor,
                                        label: Text(
                                          AppLocalizations.instance
                                              .translate('transactions_out'),
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                          ),
                                        ),
                                        selected: _filterChoice == 'out',
                                        onSelected: (_) => _handleSelect('out'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 10),
                            ],
                          );
                        } else {
                          return Container();
                        }
                      },
                    ),
                  ),
                ),
              ),

        Positioned(
          top: 80,
          left: 80,
          right: 80,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              print('BALANCE_PRIVACY_TOGGLE_TAPPED');
              context.read<AppSettingsProvider>().toggleHideWalletBalances();
            },
            child: const SizedBox(
              height: 70,
            ),
          ),
        ),
      ],
    ); // End of the return Stack
  } // Missing this closing brace for the build method
} // Missing this closing brace for the class
