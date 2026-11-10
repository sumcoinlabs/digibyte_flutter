import 'dart:async';

import 'package:digibyte/data_sources/pending_tx_retry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicate discovery sends one request', () {
    final requests = <String>[];
    final retry = PendingTxRetry(
      request: requests.add,
      canRequest: () => true,
    );

    retry.track('tx1');
    retry.track('tx1');

    expect(requests, ['tx1']);
    expect(retry.pendingCount, 1);
    retry.dispose();
  });

  test('unavailable response retries, then success stops retries', () async {
    final requests = <String>[];
    final retry = PendingTxRetry(
      request: requests.add,
      canRequest: () => true,
      responseTimeout: const Duration(seconds: 1),
      retryDelays: [const Duration(milliseconds: 5)],
    );

    retry.track('tx2');
    retry.unavailable('tx2');

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(requests, ['tx2', 'tx2']);

    retry.succeeded('tx2');
    expect(retry.pendingCount, 0);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(requests.length, 2);

    retry.dispose();
  });

  test('missing response times out and retry count is bounded', () async {
    final requests = <String>[];
    final exhausted = <String>[];
    final retry = PendingTxRetry(
      request: requests.add,
      canRequest: () => true,
      onExhausted: exhausted.add,
      responseTimeout: const Duration(milliseconds: 10),
      retryDelays: [const Duration(milliseconds: 5)],
    );

    retry.track('tx3');

    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(requests, ['tx3', 'tx3']);
    expect(exhausted, ['tx3']);
    expect(retry.pendingCount, 0);

    retry.dispose();
  });

  test('pending request survives a connection interruption', () async {
    final requests = <String>[];
    bool connected = true;

    final retry = PendingTxRetry(
      request: requests.add,
      canRequest: () => connected,
      responseTimeout: const Duration(milliseconds: 15),
      retryDelays: [const Duration(milliseconds: 5)],
    );

    retry.track('tx4');
    connected = false;
    retry.pause();

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(requests.length, 1);

    connected = true;
    retry.resume();
    expect(requests.length, 2);

    retry.succeeded('tx4');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(requests.length, 2);
    expect(retry.pendingCount, 0);

    retry.dispose();
  });

  test('later notification can retry an exhausted transaction', () {
    final requests = <String>[];
    final retry = PendingTxRetry(
      request: requests.add,
      canRequest: () => true,
      retryDelays: [],
    );

    retry.track('tx5');
    retry.unavailable('tx5');

    expect(retry.pendingCount, 0);

    retry.track('tx5');
    expect(requests.length, 2);

    retry.dispose();
  });
}
