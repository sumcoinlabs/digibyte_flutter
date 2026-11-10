import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data_sources/data_source.dart';

enum BackendConnectionState { waiting, connected, offline }

class ConnectionProvider with ChangeNotifier {
  late DataSource _dataSource;
  StreamSubscription<dynamic>? _dataSourceSubscription;
  Timer? _initialConnectionTimer;
  bool _connectionWaitExpired = false;

  // Method to switch the data source.
  void setDataSource(DataSource newDataSource) {
    _dataSourceSubscription?.cancel();
    _dataSource = newDataSource;
    _initialConnectionTimer?.cancel();
    _connectionWaitExpired = false;
    _initialConnectionTimer = Timer(const Duration(seconds: 5), () {
      _connectionWaitExpired = true;
      notifyListeners();
    });
    _dataSourceSubscription =
        _dataSource.listenerNotifierStream().listen((event) {
      notifyListeners();
    });
  }

  Future<bool> init(
    walletName, {
    bool scanMode = false,
    bool requestedFromWalletHome = false,
    bool fromConnectivityChangeOrLifeCycle = false,
  }) async {
    return await _dataSource.init(
      walletName,
      requestedFromWalletHome: requestedFromWalletHome,
      fromConnectivityChangeOrLifeCycle: fromConnectivityChangeOrLifeCycle,
    );
  }

  BackendConnectionState get connectionState {
    final actual = _dataSource.connectionState;
    if (_connectionWaitExpired && actual == BackendConnectionState.waiting) {
      return BackendConnectionState.offline;
    }
    return actual;
  }

  Future<void> closeConnection([bool intentional = true]) async {
    if (intentional) {
      _initialConnectionTimer?.cancel();
      _initialConnectionTimer = null;
    }
    await _dataSource.closeConnection(intentional);
  }

  void subscribeToScriptHashes(Map scriptHashes) {
    _dataSource.subscribeToScriptHashes(scriptHashes);
  }

  Map<String, List?> get paperWalletUtxos => _dataSource.paperWalletUtxos;

  void cleanPaperWallet() {
    _dataSource.paperWalletUtxos = {};
  }

  void requestPaperWalletUtxos(String hashId, String address) {
    _dataSource.requestPaperWalletUtxos(hashId, address);
  }

  void broadcastTransaction(String txHash, String txId) {
    _dataSource.broadcastTransaction(txHash, txId);
  }

  List get openReplies {
    return _dataSource.openReplies;
  }

  Map get listenedAddresses {
    return _dataSource.addresses;
  }

  int get latestBlock {
    return _dataSource.latestBlock;
  }

  void requestTxUpdate(String txId) {
    _dataSource.requestTxUpdate(txId);
  }

  @override
  void dispose() {
    _initialConnectionTimer?.cancel();
    _dataSourceSubscription?.cancel();
    super.dispose();
  }
}
