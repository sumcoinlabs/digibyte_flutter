import 'dart:async';

import 'package:digibyte/data_sources/data_source.dart';
import 'package:digibyte/providers/connection_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class SimulatedElectrumServer extends DataSource {
  final _events = StreamController<String>.broadcast();

  @override
  Stream listenerNotifierStream() => _events.stream;

  void changeConnection(BackendConnectionState state) {
    connectionState = state;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    _events.add('connection changed');
  }

  Future<void> shutdown() => _events.close();
}

void main() {
  testWidgets(
    'Electrum outage: spinner state ends after five seconds',
    (tester) async {
      final server = SimulatedElectrumServer();
      final provider = ConnectionProvider();

      provider.setDataSource(server);

      // The simulated server never responds.
      expect(
        provider.connectionState,
        BackendConnectionState.waiting,
      );

      await tester.pump(
        const Duration(seconds: 4, milliseconds: 900),
      );

      expect(
        provider.connectionState,
        BackendConnectionState.waiting,
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(
        provider.connectionState,
        BackendConnectionState.offline,
      );

      // The server becomes reachable later.
      server.changeConnection(
        BackendConnectionState.connected,
      );

      expect(
        provider.connectionState,
        BackendConnectionState.connected,
      );

      // Another outage should not restart endless spinning.
      server.changeConnection(
        BackendConnectionState.waiting,
      );

      expect(
        provider.connectionState,
        BackendConnectionState.offline,
      );

      provider.dispose();
      await server.shutdown();
    },
  );

  testWidgets(
    'Successful Electrum connection remains Connected',
    (tester) async {
      final server = SimulatedElectrumServer();
      final provider = ConnectionProvider();

      provider.setDataSource(server);

      server.changeConnection(
        BackendConnectionState.connected,
      );

      await tester.pump(const Duration(seconds: 6));

      expect(
        provider.connectionState,
        BackendConnectionState.connected,
      );

      provider.dispose();
      await server.shutdown();
    },
  );

  testWidgets(
    'Leaving the wallet cancels the connection timer',
    (tester) async {
      final server = SimulatedElectrumServer();
      final provider = ConnectionProvider();

      provider.setDataSource(server);

      await provider.closeConnection();

      await tester.pump(const Duration(seconds: 6));

      expect(
        provider.connectionState,
        BackendConnectionState.waiting,
      );

      provider.dispose();
      await server.shutdown();
    },
  );
}
