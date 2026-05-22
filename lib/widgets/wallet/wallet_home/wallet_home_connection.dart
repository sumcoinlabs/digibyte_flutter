import 'package:flutter/material.dart';

import '../../../providers/connection_provider.dart';
import '/../tools/app_localizations.dart';
import '/../widgets/loading_indicator.dart';

class WalletHomeConnection extends StatelessWidget {
  final BackendConnectionState _connectionState;
  const WalletHomeConnection(this._connectionState, {super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 430;
    final isVeryCompact = screenWidth < 380;

    final iconSize = isVeryCompact
        ? 16.0
        : isCompact
            ? 17.0
            : 18.0;
    final textSize = isVeryCompact
        ? 17.0
        : isCompact
            ? 18.0
            : 19.0;
    final spacing = isVeryCompact ? 7.0 : 8.0;
    final letterSpacing = isVeryCompact ? 1.6 : 1.9;

    Widget widget;
    if (_connectionState == BackendConnectionState.connected) {
      widget = Text(
        AppLocalizations.instance.translate('wallet_connected'),
        style: TextStyle(
          color: Colors.grey[100],
          letterSpacing: letterSpacing,
          fontSize: textSize,
          fontWeight: FontWeight.w600,
        ),
      );
    } else if (_connectionState == BackendConnectionState.offline) {
      widget = Text(
        AppLocalizations.instance.translate('wallet_offline'),
        style: TextStyle(
          color: Colors.grey[100],
          letterSpacing: letterSpacing,
          fontSize: textSize,
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      widget = const SizedBox(width: 70, child: LoadingIndicator());
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/icon/dgb-icon-white-256.png',
          width: iconSize,
        ),
        SizedBox(width: spacing),
        widget,
      ],
    );
  }
}
