import 'package:flutter/material.dart';

import '../../../providers/connection_provider.dart';
import '/../tools/app_localizations.dart';
import '/../widgets/loading_indicator.dart';

class WalletHomeConnection extends StatelessWidget {
  final BackendConnectionState _connectionState;
  const WalletHomeConnection(this._connectionState, {super.key});

  @override
  Widget build(BuildContext context) {
    Widget widget;
    if (_connectionState == BackendConnectionState.connected) {
      widget = Text(
        AppLocalizations.instance.translate('wallet_connected'),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          letterSpacing: 1.6,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      );
    } else if (_connectionState == BackendConnectionState.offline) {
      widget = Text(
        AppLocalizations.instance.translate('wallet_offline'),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 20,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w500,
        ),
      );
    } else {
      widget = const SizedBox(width: 88, child: LoadingIndicator());
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/icon/dgb-icon-white-256.png',
          width: 24,
        ),
        const SizedBox(
          width: 12,
        ),
        widget,
      ],
    );
  }
}
