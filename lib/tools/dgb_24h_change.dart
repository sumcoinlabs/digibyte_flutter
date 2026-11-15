import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'logger_wrapper.dart';

/// Public market data only. No wallet information is included in requests.
class Dgb24hSnapshot {
  const Dgb24hSnapshot({
    required this.percent,
    required this.source,
    required this.updatedAt,
    this.stale = false,
    this.error,
  });

  final double? percent;
  final String source;
  final DateTime? updatedAt;
  final bool stale;
  final String? error;

  bool get available => percent != null;
}

/// Polls only while a wallet screen is visible, with one shared app-wide cache.
/// Binance is preferred DGB/USDT data; CoinPaprika is the USD fallback.
class Dgb24hChangeService {
  Dgb24hChangeService({http.Client? client, DateTime Function()? clock})
      : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  static final Dgb24hChangeService shared = Dgb24hChangeService();

  /// The UI checks once a minute. Binance is preferred; each source is rate-limited.
  static const Duration refreshInterval = Duration(minutes: 1);
  static const Duration coinPaprikaInterval = Duration(minutes: 5);
  static const Duration binanceInterval = Duration(minutes: 1);
  static const Duration maxSourceAge = Duration(hours: 2);
  static const Duration maxCachedAge = Duration(hours: 24);
  static const Duration currentDataAge = Duration(minutes: 15);

  static const _savedPercent = 'dgb24h_percent_v1';
  static const _savedSource = 'dgb24h_source_v1';
  static const _savedAt = 'dgb24h_timestamp_v1';

  static final Uri _paprikaUrl =
      Uri.parse('https://api.coinpaprika.com/v1/tickers/dgb-digibyte');
  static final Uri _binanceUrl = Uri.parse(
    'https://data-api.binance.vision/api/v3/ticker/24hr?symbol=DGBUSDT',
  );

  final http.Client _client;
  final DateTime Function() _clock;
  Dgb24hSnapshot? _lastGood;
  Dgb24hSnapshot? _lastResult;
  DateTime? _lastPaprikaAttempt;
  DateTime? _lastBinanceAttempt;
  DateTime? _paprikaBlockedUntil;
  DateTime? _binanceBlockedUntil;
  Future<Dgb24hSnapshot>? _inFlight;
  bool _diskLoaded = false;

  /// Show the saved price before waiting on network requests.
  Future<Dgb24hSnapshot?> cachedSnapshot() async {
    await _restoreCache();
    if (_lastGood == null) return null;
    return _previousOrUnavailable(_clock().toUtc(), const []);
  }

  /// Concurrent widgets share the same request and never cause duplicate calls.
  /// `force` bypasses normal timing, but never a 429/402/404 cooldown.
  Future<Dgb24hSnapshot> fetch({bool force = false}) {
    if (_inFlight != null) return _inFlight!;
    return _inFlight = _refresh(force: force).whenComplete(() {
      _inFlight = null;
    });
  }

  bool _due(
    DateTime now,
    DateTime? lastAttempt,
    DateTime? blockedUntil,
    Duration interval, {
    required bool force,
  }) {
    if (blockedUntil != null && now.isBefore(blockedUntil)) return false;
    if (force || lastAttempt == null) return true;
    final elapsed = now.difference(lastAttempt);
    return elapsed.isNegative || elapsed >= interval;
  }

  Future<Dgb24hSnapshot> _refresh({required bool force}) async {
    await _restoreCache();
    final now = _clock().toUtc();
    final duePaprika = _due(
      now,
      _lastPaprikaAttempt,
      _paprikaBlockedUntil,
      coinPaprikaInterval,
      force: force,
    );
    final dueBinance = _due(
      now,
      _lastBinanceAttempt,
      _binanceBlockedUntil,
      binanceInterval,
      force: force,
    );
    // A successful Binance result remains current until its next poll.
    // Do not contact the backup simply because its timer is due.
    if (!dueBinance &&
        _lastResult?.source == 'Binance DGB/USDT' &&
        _lastResult?.error == null) {
      return _lastResult = _previousOrUnavailable(now, const []);
    }

    if (!duePaprika && !dueBinance) {
      return _lastResult = _previousOrUnavailable(now, const []);
    }

    final failures = <String>[];
    // Binance DGB/USDT is preferred: poll it at most once per minute.
    // Only request the CoinPaprika aggregated DGB/USD feed if Binance fails
    // or is cooling down. Its own five-minute limit is independent.
    if (dueBinance) {
      _lastBinanceAttempt = now;
      try {
        return await _accept(await _readBinance());
      } catch (error) {
        _recordFailure(error, 'Binance', now, failures);
      }
    }

    if (duePaprika) {
      _lastPaprikaAttempt = now;
      try {
        return await _accept(await _readCoinPaprika());
      } catch (error) {
        _recordFailure(error, 'CoinPaprika', now, failures);
      }
    }

    return _lastResult = _previousOrUnavailable(now, failures);
  }

  Future<Dgb24hSnapshot> _readCoinPaprika() async {
    final response =
        await _client.get(_paprikaUrl).timeout(const Duration(seconds: 4));
    _checkStatus(response, 'CoinPaprika');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['id'] != 'dgb-digibyte' ||
        decoded['symbol'] != 'DGB') {
      throw const FormatException('unexpected DGB ticker response');
    }
    final quotes = decoded['quotes'];
    if (quotes is! Map || quotes['USD'] is! Map) {
      throw const FormatException('missing USD 24-hour change');
    }
    final percent = _validPercent(quotes['USD']['percent_change_24h']);
    final updated = DateTime.tryParse('${decoded['last_updated']}')?.toUtc();
    _validateTime(updated, 'CoinPaprika');
    LoggerWrapper.logInfo('DGB24H', 'market',
        '[DGB24H] CoinPaprika raw=${quotes['USD']['percent_change_24h']} percent=$percent updated=$updated');
    return Dgb24hSnapshot(
      percent: percent,
      source: 'CoinPaprika',
      updatedAt: updated,
    );
  }

  Future<Dgb24hSnapshot> _readBinance() async {
    // Binance is exchange-specific DGB/USDT, not the aggregate DGB/USD index.
    final response =
        await _client.get(_binanceUrl).timeout(const Duration(seconds: 4));
    _checkStatus(response, 'Binance');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['symbol'] != 'DGBUSDT') {
      throw const FormatException('DGB/USDT market unavailable');
    }
    final volume = double.tryParse('${decoded['quoteVolume']}');
    if (volume == null || !volume.isFinite || volume <= 0) {
      throw const FormatException('DGB/USDT has no current trading volume');
    }
    final percent = _validPercent(decoded['priceChangePercent']);
    final closeMs = decoded['closeTime'];
    if (closeMs is! num) {
      throw const FormatException('missing market timestamp');
    }
    final updated = DateTime.fromMillisecondsSinceEpoch(
      closeMs.toInt(),
      isUtc: true,
    );
    _validateTime(updated, 'Binance');
    LoggerWrapper.logInfo('DGB24H', 'market',
        '[DGB24H] Binance raw=${decoded['priceChangePercent']} percent=$percent updated=$updated');
    return Dgb24hSnapshot(
      percent: percent,
      source: 'Binance DGB/USDT',
      updatedAt: updated,
    );
  }

  void _recordFailure(
    Object error,
    String provider,
    DateTime now,
    List<String> failures,
  ) {
    final message = '$provider: ${_reason(error)}';
    failures.add(message);
    LoggerWrapper.logWarn('DGB24H', provider, message);
    if (error is _FeedError && error.cooldown != null) {
      if (provider == 'CoinPaprika') {
        _paprikaBlockedUntil = now.add(error.cooldown!);
      } else {
        _binanceBlockedUntil = now.add(error.cooldown!);
      }
    }
  }

  Dgb24hSnapshot _previousOrUnavailable(DateTime now, List<String> failures) {
    final previous = _lastGood;
    final message = failures.isEmpty ? _lastResult?.error : failures.join('; ');
    LoggerWrapper.logInfo('DGB24H', 'market',
        '[DGB24H] fallback source=${previous?.source} percent=${previous?.percent} error=$message');
    if (previous != null && previous.updatedAt != null) {
      final age = now.difference(previous.updatedAt!);
      if (!age.isNegative && age <= maxCachedAge) {
        return Dgb24hSnapshot(
          percent: previous.percent,
          source: previous.source,
          updatedAt: previous.updatedAt,
          stale: age > currentDataAge,
          error: message,
        );
      }
    }
    return Dgb24hSnapshot(
      percent: null,
      source: '',
      updatedAt: null,
      error: message ?? 'Both market feeds are unavailable.',
    );
  }

  Future<Dgb24hSnapshot> _accept(Dgb24hSnapshot value) async {
    _lastGood = value;
    _lastResult = value;
    LoggerWrapper.logInfo('DGB24H', 'market',
        '[DGB24H] accepted source=${value.source} percent=${value.percent} stale=${value.stale}');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_savedPercent, value.percent!);
      await prefs.setString(_savedSource, value.source);
      await prefs.setString(_savedAt, value.updatedAt!.toIso8601String());
    } catch (_) {
      LoggerWrapper.logWarn('DGB24H', 'cache', 'Cache unavailable');
    }
    return value;
  }

  Future<void> _restoreCache() async {
    if (_diskLoaded) return;
    _diskLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final percent = prefs.getDouble(_savedPercent);
      final source = prefs.getString(_savedSource);
      final iso = prefs.getString(_savedAt);
      if (percent == null ||
          !percent.isFinite ||
          source == null ||
          iso == null) {
        return;
      }
      if (source != 'CoinPaprika' && source != 'Binance DGB/USDT') return;
      final updatedAt = DateTime.tryParse(iso)?.toUtc();
      if (updatedAt == null) return;
      final age = _clock().toUtc().difference(updatedAt);
      if (age.isNegative || age > maxCachedAge) return;
      _lastGood ??= Dgb24hSnapshot(
        percent: percent,
        source: source,
        updatedAt: updatedAt,
      );
    } catch (_) {
      // Cache access should never interfere with the wallet screen.
    }
  }

  double _validPercent(Object? raw) {
    final parsed = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (parsed == null || !parsed.isFinite || parsed.abs() > 100000) {
      throw const FormatException('invalid 24-hour percentage');
    }
    return parsed;
  }

  void _validateTime(DateTime? timestamp, String provider) {
    if (timestamp == null) throw FormatException('$provider timestamp missing');
    final age = _clock().toUtc().difference(timestamp);
    if (age < const Duration(minutes: -10) || age > maxSourceAge) {
      throw FormatException('$provider data is outdated');
    }
  }

  void _checkStatus(http.Response response, String provider) {
    final status = response.statusCode;
    if (status == 200) return;
    if (status == 429) {
      throw const _FeedError('request limit reached', Duration(minutes: 15));
    }
    if (status == 402) {
      throw const _FeedError('free API quota reached', Duration(hours: 24));
    }
    if (status == 418) {
      throw const _FeedError(
          'temporarily blocked by provider', Duration(hours: 1));
    }
    if (status == 400 || status == 404) {
      throw _FeedError(
          '$provider DGB market unavailable', const Duration(hours: 1));
    }
    throw _FeedError('HTTP $status', null);
  }

  String _reason(Object error) {
    if (error is _FeedError) return error.message;
    if (error is TimeoutException) return 'request timed out';
    if (error is FormatException) return error.message;
    if (error is http.ClientException) return 'network connection failed';
    return 'network or service unavailable';
  }
}

class _FeedError implements Exception {
  const _FeedError(this.message, this.cooldown);
  final String message;
  final Duration? cooldown;
}
