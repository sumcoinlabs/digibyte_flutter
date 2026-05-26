// ignore_for_file: prefer_typing_uninitialized_variables

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/available_coins.dart';
import '../providers/connection_provider.dart';
import '../providers/server_provider.dart';
import '../providers/wallet_provider.dart';
import '../tools/logger_wrapper.dart';
import 'data_source.dart';

enum ElectrumServerType { ssl, wss }

class ElectrumBackend extends DataSource {
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  StreamSubscription? _offlineSubscription;
  final WalletProvider walletProvider;
  final ServerProvider _servers;
  final StreamController _listenerNotifier = StreamController.broadcast();
  bool _closedIntentionally = false;
  int _connectionAttempt = 0;
  int _resetAttempt = 1;
  dynamic _connection; // Kept as dynamic for SSL/WebSocket compatibility
  late String coinName;
  String? _serverUrl; // Made nullable with safeguard
  List? _availableServers; // Made nullable with safeguard
  ElectrumServerType? _serverType; // Made nullable with safeguard
  late double _requiredProtocol;

  ElectrumBackend(
    this.walletProvider,
    this._servers,
  );

  @override
  Stream listenerNotifierStream() {
    return _listenerNotifier.stream;
  }

  @override
  Future<bool> init(
    String walletName, {
    bool requestedFromWalletHome = false,
    bool fromConnectivityChangeOrLifeCycle = false,
  }) async {
    await _servers.init(walletName);
    _requiredProtocol =
        AvailableCoins.getSpecificCoin(walletName).electrumRequiredProtocol;

    var connectivityResult = await (Connectivity().checkConnectivity());

    if (connectivityResult.contains(ConnectivityResult.none)) {
      updateConnectionState = BackendConnectionState.offline;

      _offlineSubscription = Connectivity()
          .onConnectivityChanged
          .listen((List<ConnectivityResult> result) async {
        if (result.isNotEmpty && result.first != ConnectivityResult.none) {
          // Connection re-established
          await _cancelSubscriptionAndCleanup();
          await closeConnection();
          cleanUpOnDone();
          init(
            walletName,
            requestedFromWalletHome: requestedFromWalletHome,
            fromConnectivityChangeOrLifeCycle: true,
          );
        } else if (result.isNotEmpty &&
            result.first == ConnectivityResult.none) {
          updateConnectionState = BackendConnectionState.offline;
        }
      });

      return false;
    } else if (_connection == null) {
      coinName = walletName;
      updateConnectionState = BackendConnectionState.waiting;
      LoggerWrapper.logInfo(
        'ElectrumConnection',
        'init',
        'init server connection',
      );
      await connect();

      if (_connection != null && _serverType != null) {
        var stream = _serverType == ElectrumServerType.ssl
            ? _connection
            : _connection!.stream;

        stream.listen(
          (elem) {
            replyHandler(elem);
          },
          onError: (error) {
            LoggerWrapper.logError(
              'ElectrumConnection',
              'init',
              error.toString(),
            );
            _connectionAttempt++;
            _attemptReconnect();
          },
          onDone: () {
            cleanUpOnDone();
            LoggerWrapper.logInfo(
              'ElectrumConnection',
              'init',
              'connection done',
            );
            _attemptReconnect();
          },
        );
        tryHandShake();
        startPingTimer();

        return true;
      }
      return false;
    } else if (fromConnectivityChangeOrLifeCycle == false &&
        _closedIntentionally == false) {
      LoggerWrapper.logInfo(
        'ElectrumConnection',
        'init',
        'connection was not reset (yet), will try again in 1 second, reset attempt $_resetAttempt',
      );
      await Future.delayed(const Duration(seconds: 1));
      if (_resetAttempt > 3) {
        await closeConnection();
      }
      _resetAttempt++;
      await init(
        walletName,
        requestedFromWalletHome: requestedFromWalletHome,
      );
    }
    return false;
  }

  Future<void> connect() async {
    _availableServers = await _servers.getServerList(coinName);
    LoggerWrapper.logInfo(
      'ElectrumConnection',
      'connect',
      'Available servers: $_availableServers',
    );

    if (_availableServers == null || _availableServers!.isEmpty) {
      throw Exception('No available servers to connect to');
    }

    if (_connectionAttempt >= _availableServers!.length) {
      _connectionAttempt = 0;
    }

    LoggerWrapper.logInfo(
      'ElectrumConnection',
      'connect',
      'connection attempt $_connectionAttempt',
    );

    _serverUrl = _availableServers![_connectionAttempt];
    LoggerWrapper.logInfo(
      'ElectrumConnection',
      'connect',
      'connecting to $_serverUrl',
    );

    try {
      if (_serverUrl!.contains('wss://')) {
        _connection = WebSocketChannel.connect(Uri.parse(_serverUrl!));
        _serverType = ElectrumServerType.wss;
      } else if (_serverUrl!.contains('ssl://') && !kIsWeb) {
        _serverType = ElectrumServerType.ssl;
        final split = _serverUrl!.split(':');
        final host = split[1].replaceAll('//', '');
        final port = int.parse(split[2]);
        _connection = await SecureSocket.connect(host, port,
            timeout: const Duration(seconds: 10));
      } else if (kIsWeb) {
        _connectionAttempt++; // Try next server on web if SSL not supported
        if (_connectionAttempt < _availableServers!.length) {
          await connect();
        } else {
          throw Exception('No WebSocket servers available for web platform');
        }
      }
    } catch (e) {
      _connectionAttempt++;
      LoggerWrapper.logError(
        'ElectrumConnection',
        'connect',
        e.toString(),
      );
      if (_connectionAttempt < _availableServers!.length) {
        await connect(); // Limited recursion with length check
      } else {
        _attemptReconnect();
      }
    }
  }

  void _attemptReconnect() {
    if (_closedIntentionally) {
      LoggerWrapper.logInfo(
        'ElectrumConnection',
        '_attemptReconnect',
        'not reconnecting because connection was closed intentionally',
      );
      return;
    }

    if (_reconnectTimer?.isActive ?? false) {
      LoggerWrapper.logInfo(
        'ElectrumConnection',
        '_attemptReconnect',
        'reconnect already scheduled',
      );
      return;
    }

    if (_availableServers == null || _availableServers!.isEmpty) {
      updateConnectionState = BackendConnectionState.offline;
      LoggerWrapper.logError(
        'ElectrumConnection',
        '_attemptReconnect',
        'no available servers to reconnect to',
      );
      return;
    }

    if (_connectionAttempt >= _availableServers!.length) {
      _connectionAttempt = 0;
    }

    updateConnectionState = BackendConnectionState.waiting;

    LoggerWrapper.logInfo(
      'ElectrumConnection',
      '_attemptReconnect',
      'scheduling full reconnect attempt $_connectionAttempt',
    );

    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      _reconnectTimer = null;
      _connection = null;
      _serverType = null;

      await init(
        coinName,
        requestedFromWalletHome: true,
        fromConnectivityChangeOrLifeCycle: true,
      );
    });
  }

  void replyReceived(String id) {
    openReplies.removeWhere((element) => element == id);
    notifyListeners();
  }

  Map get listenedAddresses {
    return addresses;
  }

  @override
  Future<void> closeConnection([bool intentional = true]) async {
    if (_connection != null) {
      _closedIntentionally = intentional;
      if (_serverType == ElectrumServerType.ssl) {
        _connection.close();
      } else if (_serverType == ElectrumServerType.wss) {
        await _connection!.sink.close();
      }
    }
    if (intentional) {
      _closedIntentionally = true;
      _connectionAttempt = 0;
      if (_reconnectTimer != null) _reconnectTimer!.cancel();
      await _cancelSubscriptionAndCleanup();
    }
  }

  Future<void> _cancelSubscriptionAndCleanup() async {
    if (_offlineSubscription != null) {
      await _offlineSubscription!.cancel();
      _offlineSubscription = null;
    }
  }

  void cleanUpOnDone() {
    _pingTimer?.cancel();
    _pingTimer = null;
    updateConnectionState = BackendConnectionState.waiting;
    _connection = null;
    addresses = {};
    latestBlock = 0;
    paperWalletUtxos = {};
    openReplies = [];
    _resetAttempt = 1;

    LoggerWrapper.logInfo(
      'ElectrumConnection',
      'cleanUpOnDone',
      'cleaned up (intentional $_closedIntentionally)',
    );

    if (!_closedIntentionally) {
      _reconnectTimer = Timer(
        const Duration(seconds: 5),
        () => init(coinName),
      );
    }
  }

  void replyHandler(dynamic reply) {
    String parsedReply;
    if (reply is Uint8List) {
      parsedReply = String.fromCharCodes(reply);
    } else {
      parsedReply = reply as String;
    }
    LoggerWrapper.logInfo('ElectrumConnection', 'replyHandler', parsedReply);
    var decoded = json.decode(parsedReply);
    var id = decoded['id'];
    var idString = id?.toString() ?? '';
    var result = decoded['result'];

    if (id != null) {
      LoggerWrapper.logInfo(
        'ElectrumConnection',
        'replyHandler',
        'id: $idString',
      );
      if (idString == 'version') {
        handleVersion(result);
      } else if (idString.startsWith('tx_')) {
        handleTx(id, result);
      } else if (idString.startsWith('utxo_')) {
        handleUtxo(id, result);
      } else if (idString.startsWith('paperwallet_')) {
        handlePaperWallet(id, result);
      } else if (idString.startsWith('broadcast_')) {
        handleBroadcast(id, result ?? decoded['error']['code'].toString());
      } else if (idString == 'blocks') {
        handleBlock(result['height']);
      } else if (addresses[idString] != null) {
        handleAddressStatus(id, result);
      } else if (idString == 'features') {
        handleFeatures(result);
      }
    } else if (decoded['params'] != null) {
      switch (decoded['method']) {
        case 'blockchain.scripthash.subscribe':
          handleScriptHashSubscribeNotification(
            decoded['params'][0],
            decoded['params'][1],
          );
          break;
        case 'blockchain.headers.subscribe':
          handleBlock(decoded['params'][0]['height']);
          break;
      }
    }
    replyReceived(idString);
  }

  void sendMessage(String method, String? id, [List? params]) {
    openReplies.add(id);
    final String encodedMessage = json.encode(
      {'id': id, 'method': method, if (params != null) 'params': params},
    );
    if (_connection != null && _serverType != null) {
      if (_serverType == ElectrumServerType.ssl) {
        _connection.add(utf8.encode(encodedMessage + '\n'));
      } else if (_serverType == ElectrumServerType.wss &&
          _connection.sink != null) {
        try {
          _connection.sink.add(encodedMessage);
        } catch (e) {
          LoggerWrapper.logError(
            'ElectrumConnection',
            'sendMessage',
            e.toString(),
          );
        }
      }
    }
  }

  void tryHandShake() async {
    var packageInfo = await PackageInfo.fromPlatform();
    sendMessage(
      'server.version',
      'version',
      ['${packageInfo.appName}-flutter-${packageInfo.version}'],
    );
    sendMessage('server.features', 'features');
  }

  void handleVersion(List result) {
    var version = double.tryParse(result.last.toString()) ?? 0.0;
    if (version < _requiredProtocol) {
      closeConnection(false);
    }
  }

  void handleFeatures(Map result) {
    if (result['genesis_hash'] ==
        AvailableCoins.getSpecificCoin(coinName).genesisHash) {
      updateConnectionState = BackendConnectionState.connected;
      sendMessage('blockchain.headers.subscribe', 'blocks');
    } else {
      LoggerWrapper.logWarn(
        'ElectrumConnection',
        'handleFeatures',
        'wrong genesis! disconnecting.',
      );
      closeConnection(false);
    }
  }

  void handleBlock(int height) {
    latestBlock = height;
    notifyListeners();
  }

  set updateConnectionState(BackendConnectionState state) {
    connectionState = state;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    _listenerNotifier.add('notify');
  }

  void handleAddressStatus(String address, String? newStatus) async {
    var oldStatus =
        await walletProvider.getWalletAddressStatus(coinName, address);
    var hash =
        addresses.entries.firstWhereOrNull((element) => element.key == address);
    if (hash != null && newStatus != oldStatus) {
      LoggerWrapper.logInfo(
        'ElectrumConnection',
        'handleAddressStatus',
        '$address status changed! $oldStatus, $newStatus',
      );
      handleScriptHashSubscribeNotification(hash.value, newStatus);
    }
  }

  void startPingTimer() {
    _pingTimer ??= Timer.periodic(
      const Duration(minutes: 7),
      (_) => sendMessage('server.ping', 'ping'),
    );
  }

  @override
  void subscribeToScriptHashes(Map scriptHashes) {
    for (var hash in scriptHashes.entries) {
      addresses[hash.key] = hash.value;
      sendMessage('blockchain.scripthash.subscribe', hash.key, [hash.value]);
    }
    notifyListeners();
  }

  void handleScriptHashSubscribeNotification(
    String? hashId,
    String? newStatus,
  ) async {
    final address = addresses.keys.firstWhere(
      (element) => addresses[element] == hashId,
      orElse: () => null,
    );
    if (address != null) {
      LoggerWrapper.logInfo(
        'ElectrumConnection',
        'handleScriptHashSubscribeNotification',
        'update for $hashId',
      );
      await walletProvider.updateAddressStatus(coinName, address, newStatus);
      sendMessage(
        'blockchain.scripthash.listunspent',
        'utxo_$address',
        [hashId],
      );
    }
  }

  @override
  void requestPaperWalletUtxos(String hashId, String address) {
    sendMessage(
      'blockchain.scripthash.listunspent',
      'paperwallet_$address',
      [hashId],
    );
  }

  void handlePaperWallet(String id, List? utxos) {
    final txAddr = id.replaceFirst('paperwallet_', '');
    paperWalletUtxos[txAddr] = utxos;
    notifyListeners();
  }

  void handleUtxo(String id, List utxos) async {
    final txAddr = id.replaceFirst('utxo_', '');
    await walletProvider.putUtxos(
      identifier: coinName,
      address: txAddr,
      utxos: utxos,
    );

    var walletTx = await walletProvider.getWalletTransactions(coinName);
    for (var utxo in utxos) {
      var res = walletTx.firstWhereOrNull(
        (element) => element.txid == utxo['tx_hash'],
      );
      if (res == null) {
        requestTxUpdate(utxo['tx_hash']);
      }
    }
  }

  @override
  void requestTxUpdate(String txId) {
    sendMessage(
      'blockchain.transaction.get',
      'tx_$txId',
      [txId, true],
    );
  }

  @override
  void broadcastTransaction(String txHash, String txId) {
    sendMessage(
      'blockchain.transaction.broadcast',
      'broadcast_$txId',
      [txHash],
    );
  }

  void handleTx(String id, Map? tx) async {
    var txId = id.replaceFirst('tx_', '');
    var addr = await walletProvider.getAddressForTx(coinName, txId);
    if (tx != null) {
      await walletProvider.putTx(
        identifier: coinName,
        address: addr,
        tx: tx,
      );
    } else {
      LoggerWrapper.logWarn('ElectrumConnection', 'handleTx', 'tx not found');
    }
  }

  void handleBroadcast(String id, String result) async {
    var txId = id.replaceFirst('broadcast_', '');
    if (result == '1') {
      LoggerWrapper.logWarn(
        'ElectrumConnection',
        'handleBroadcast',
        'tx rejected by server',
      );
      await walletProvider.updateRejected(coinName, txId);
    } else if (txId != 'import') {
      await walletProvider.updateBroadcasted(coinName, txId);
    }
  }

  String get connectedServerUrl {
    return connectionState == BackendConnectionState.connected
        ? _serverUrl ?? ''
        : '';
  }

  @override
  void dispose() {
    _listenerNotifier.close();
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _cancelSubscriptionAndCleanup();
    closeConnection(true);
    // Removed super.dispose() since DataSource doesn't define it
  }
}
