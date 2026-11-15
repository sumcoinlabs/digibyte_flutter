import 'dart:async';
import 'dart:convert';

import 'package:digibyte/tools/dgb_24h_change.dart';
import 'package:digibyte/widgets/wallet/dgb_24h_change_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 11, 14, 20);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  String paprika(DateTime time, double change) => jsonEncode({
        'id': 'dgb-digibyte',
        'symbol': 'DGB',
        'last_updated': time.toIso8601String(),
        'quotes': {
          'USD': {'percent_change_24h': change}
        },
      });

  String binance(DateTime time, double change) => jsonEncode({
        'symbol': 'DGBUSDT',
        'priceChangePercent': change.toString(),
        'quoteVolume': '125000',
        'closeTime': time.millisecondsSinceEpoch,
      });

  test('Binance is preferred; immediate repeats use cache', () async {
    var calls = 0;
    final service = Dgb24hChangeService(
      clock: () => now,
      client: MockClient((request) async {
        calls++;
        expect(request.url.host, 'data-api.binance.vision');
        return http.Response(binance(now, -2.25), 200);
      }),
    );
    final first = await service.fetch();
    expect(first.percent, -2.25);
    expect(first.source, 'Binance DGB/USDT');
    await service.fetch();
    expect(calls, 1);
  });

  test('CoinPaprika backs up Binance when Binance is rate-limited', () async {
    final calls = <String>[];
    final service = Dgb24hChangeService(
      clock: () => now,
      client: MockClient((request) async {
        calls.add(request.url.host);
        if (request.url.host == 'data-api.binance.vision') {
          return http.Response('rate limited', 429);
        }
        return http.Response(paprika(now, -3.21), 200);
      }),
    );
    final result = await service.fetch();
    expect(calls, ['data-api.binance.vision', 'api.coinpaprika.com']);
    expect(result.source, 'CoinPaprika');
    expect(result.percent, -3.21);
  });

  test('both feeds failing explains both errors', () async {
    final service = Dgb24hChangeService(
      clock: () => now,
      client: MockClient((request) async => http.Response('', 503)),
    );
    final result = await service.fetch();
    expect(result.available, isFalse);
    expect(result.error, contains('Binance'));
    expect(result.error, contains('CoinPaprika'));
  });

  test('invalid Binance response falls back to CoinPaprika', () async {
    final service = Dgb24hChangeService(
      clock: () => now,
      client: MockClient((request) async {
        if (request.url.host == 'data-api.binance.vision') {
          return http.Response('{"symbol":"NOT_DGB"}', 200);
        }
        return http.Response(
            paprika(now.subtract(const Duration(minutes: 1)), 2.1), 200);
      }),
    );
    expect((await service.fetch()).source, 'CoinPaprika');
  });

  test('Binance polls each 60s without unnecessarily calling backup', () async {
    var clockNow = now;
    var binanceCalls = 0;
    var paprikaCalls = 0;
    final service = Dgb24hChangeService(
      clock: () => clockNow,
      client: MockClient((request) async {
        if (request.url.host == 'api.coinpaprika.com') {
          paprikaCalls++;
          return http.Response(paprika(clockNow, 0), 200);
        }
        binanceCalls++;
        return http.Response(binance(clockNow, binanceCalls.toDouble()), 200);
      }),
    );
    expect((await service.fetch()).percent, 1);
    for (var minute = 1; minute <= 6; minute++) {
      clockNow = now.add(Duration(minutes: minute));
      expect((await service.fetch()).percent, (minute + 1).toDouble());
      await service.fetch();
      expect(binanceCalls, minute + 1);
    }
    expect(paprikaCalls, 0);
  });

  test('Binance rate limit cools down; backup refreshes at most every 5m',
      () async {
    var clockNow = now;
    var binanceCalls = 0;
    var paprikaCalls = 0;
    final service = Dgb24hChangeService(
      clock: () => clockNow,
      client: MockClient((request) async {
        if (request.url.host == 'data-api.binance.vision') {
          binanceCalls++;
          return http.Response('', 429);
        }
        paprikaCalls++;
        return http.Response(paprika(clockNow, paprikaCalls.toDouble()), 200);
      }),
    );
    expect((await service.fetch()).source, 'CoinPaprika');
    for (var minute = 1; minute <= 6; minute++) {
      clockNow = now.add(Duration(minutes: minute));
      expect((await service.fetch()).available, isTrue);
    }
    expect(binanceCalls, 1);
    expect(paprikaCalls, 2);
  });

  test('unlisted Binance pair gets 1h cooldown and uses backup', () async {
    var clockNow = now;
    var binanceCalls = 0;
    var paprikaCalls = 0;
    final service = Dgb24hChangeService(
      clock: () => clockNow,
      client: MockClient((request) async {
        if (request.url.host == 'data-api.binance.vision') {
          binanceCalls++;
          return http.Response('{"code":-1121}', 400);
        }
        paprikaCalls++;
        return http.Response(paprika(clockNow, -3), 200);
      }),
    );
    expect((await service.fetch()).source, 'CoinPaprika');
    for (var minute = 1; minute <= 10; minute++) {
      clockNow = now.add(Duration(minutes: minute));
      expect((await service.fetch()).available, isTrue);
    }
    expect(binanceCalls, 1);
    expect(paprikaCalls, 3);
  });

  test('recent valid reading survives temporary failure of both feeds',
      () async {
    var clockNow = now;
    var requests = 0;
    final service = Dgb24hChangeService(
      clock: () => clockNow,
      client: MockClient((request) async {
        requests++;
        if (requests == 1) {
          return http.Response(binance(clockNow, 1.23), 200);
        }
        return http.Response('', 503);
      }),
    );

    expect((await service.fetch()).percent, 1.23);

    clockNow = now.add(const Duration(minutes: 1));
    final saved = await service.fetch();

    expect(saved.percent, 1.23);
    expect(saved.source, 'Binance DGB/USDT');
    expect(saved.error, contains('Binance'));
    expect(saved.error, contains('CoinPaprika'));
    expect(saved.stale, isFalse);
  });

  testWidgets('neutral 24hr title, red loss, info icon, no visible source',
      (tester) async {
    final service = Dgb24hChangeService(
      clock: () => now,
      client: MockClient(
          (request) async => http.Response(binance(now, -3.14), 200)),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Dgb24hChangeIndicator(service: service)),
    ));
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.text('24hr:'));
    expect(title.style?.color, Colors.grey[300]);
    final change = tester.widget<Text>(find.text('-3.14%'));
    expect(change.style?.color, const Color(0xFFFFC5A0));
    expect(change.style?.fontSize, 18);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(find.textContaining('Binance'), findsNothing);
    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('Source: Binance'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('green gain on Binance and grey neutral on failure',
      (tester) async {
    final green = Dgb24hChangeService(
      clock: () => now,
      client:
          MockClient((request) async => http.Response(binance(now, 3.21), 200)),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Dgb24hChangeIndicator(service: green)),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('+3.21%')).style?.color,
        const Color(0xFFA4E8B2));
    await tester.pumpWidget(const SizedBox.shrink());

    // Start with an empty cache when testing complete feed failure.
    SharedPreferences.setMockInitialValues({});
    final unavailable = Dgb24hChangeService(
      clock: () => now,
      client: MockClient((request) async => http.Response('', 503)),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Dgb24hChangeIndicator(service: unavailable)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('Binance:'), findsOneWidget);
    expect(find.textContaining('CoinPaprika:'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('no horizontal overflow at 320/375/430 and two themes',
      (tester) async {
    final service = Dgb24hChangeService(
      clock: () => now,
      client: MockClient(
          (request) async => http.Response(binance(now, -10.93), 200)),
    );
    for (final width in [320.0, 375.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(body: Dgb24hChangeIndicator(service: service)),
          ));
          await tester.pumpAndSettle();
          final titleRect =
              tester.getRect(find.byKey(const Key('dgb24hTitle')));
          final valueRect =
              tester.getRect(find.byKey(const Key('dgb24hChangeLabel')));
          expect(titleRect.left, greaterThanOrEqualTo(-0.01));
          expect(valueRect.right, lessThanOrEqualTo(width + 0.01));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('timer fetches every 60s and stops after leaving Transactions',
      (tester) async {
    var clockNow = now;
    var binanceCalls = 0;
    final service = Dgb24hChangeService(
      clock: () => clockNow,
      client: MockClient((request) async {
        binanceCalls++;
        return http.Response(binance(clockNow, binanceCalls.toDouble()), 200);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Dgb24hChangeIndicator(service: service)),
    ));
    await tester.pumpAndSettle();
    expect(binanceCalls, 1);
    clockNow = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(binanceCalls, 2);
    expect(find.text('+2.00%'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    clockNow = now.add(const Duration(minutes: 3));
    await tester.pump(const Duration(minutes: 2));
    expect(binanceCalls, 2);
  });

  testWidgets('loading animation stops after price arrives', (tester) async {
    final pending = Completer<http.Response>();

    final service = Dgb24hChangeService(
      clock: () => now,
      client: MockClient((request) => pending.future),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Dgb24hChangeIndicator(service: service),
      ),
    ));

    await tester.pump();

    expect(
      find.byKey(const Key('dgb24hLoading')),
      findsOneWidget,
    );

    expect(find.text('Checking…'), findsOneWidget);

    pending.complete(
      http.Response(binance(now, -1.10), 200),
    );

    await tester.pumpAndSettle();

    expect(find.text('-1.10%'), findsOneWidget);
    expect(
      find.byKey(const Key('dgb24hLoading')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('cached price displays during refresh', (tester) async {
    SharedPreferences.setMockInitialValues({
      'dgb24h_percent_v1': 1.75,
      'dgb24h_source_v1': 'Binance DGB/USDT',
      'dgb24h_timestamp_v1':
          now.subtract(const Duration(minutes: 1)).toIso8601String(),
    });

    final pending = Completer<http.Response>();

    final service = Dgb24hChangeService(
      clock: () => now,
      client: MockClient((request) => pending.future),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Dgb24hChangeIndicator(service: service),
      ),
    ));

    await tester.pump(const Duration(milliseconds: 40));

    expect(find.text('+1.75%'), findsOneWidget);

    pending.complete(
      http.Response(binance(now, -2.10), 200),
    );

    await tester.pumpAndSettle();

    expect(find.text('-2.10%'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'loading indicator wraps on narrow screens and large fonts',
    (tester) async {
      final pending = Completer<http.Response>();

      final service = Dgb24hChangeService(
        clock: () => now,
        client: MockClient((request) => pending.future),
      );

      for (final width in [320.0, 375.0, 430.0]) {
        await tester.binding.setSurfaceSize(
          Size(width, 900),
        );

        for (final scale in [1.0, 1.5, 2.0]) {
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Dgb24hChangeIndicator(
                  service: service,
                ),
              ),
            ),
          );

          await tester.pump();

          expect(
            find.byKey(const Key('dgb24hLoading')),
            findsOneWidget,
          );

          expect(
            find.text('Checking…'),
            findsOneWidget,
          );

          expect(tester.takeException(), isNull);

          await tester.pumpWidget(
            const SizedBox.shrink(),
          );
        }
      }

      pending.complete(
        http.Response(binance(now, -1.10), 200),
      );

      await tester.pump();
      await tester.binding.setSurfaceSize(null);
    },
  );
}
