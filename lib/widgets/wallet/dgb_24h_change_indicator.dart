import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../tools/dgb_24h_change.dart';

/// Compact market change: shown only on the Transactions tab.
class Dgb24hChangeIndicator extends StatefulWidget {
  const Dgb24hChangeIndicator({super.key, this.service});

  final Dgb24hChangeService? service;

  @override
  State<Dgb24hChangeIndicator> createState() => _Dgb24hChangeIndicatorState();
}

class _Dgb24hChangeIndicatorState extends State<Dgb24hChangeIndicator>
    with WidgetsBindingObserver {
  Dgb24hSnapshot? _snapshot;
  Timer? _timer;
  bool _loading = true;

  Dgb24hChangeService get _service =>
      widget.service ?? Dgb24hChangeService.shared;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    _loadInitial();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Dgb24hChangeService.refreshInterval,
      (_) => _update(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _update();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _loadInitial() async {
    final cached = await _service.cachedSnapshot();
    if (!mounted) return;

    if (cached != null) {
      setState(() => _snapshot = cached);
    }

    await _update();
  }

  Future<void> _update() async {
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final next = await _service.fetch();
      if (!mounted) return;

      setState(() {
        _snapshot = next;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _snapshot ??= const Dgb24hSnapshot(
          percent: null,
          source: '',
          updatedAt: null,
          error: 'Market data could not be reached.',
        );
      });
    }
  }

  String _detailMessage(Dgb24hSnapshot? item) {
    if (item == null) return 'Checking market data…';

    final source = item.source.isEmpty ? 'Unavailable' : item.source;

    final updated = item.updatedAt == null
        ? 'Not available'
        : DateFormat('MMM d, h:mm a').format(item.updatedAt!.toLocal());

    final status = _loading && !item.available
        ? 'Checking'
        : !item.available
            ? 'Unavailable'
            : item.stale
                ? 'Saved price'
                : item.error != null
                    ? 'Showing last price'
                    : 'Current';

    final error = item.error == null
        ? ''
        : '\nProblem: ${item.error!.replaceAll('; ', '\n')}';

    return 'Status: $status\n'
        'Source: $source\n'
        'Updated: $updated$error';
  }

  void _details(Dgb24hSnapshot? item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DGB · 24hr change'),
        content: SingleChildScrollView(
          child: Text(
            _detailMessage(item),
            style: const TextStyle(
              fontSize: 16,
              height: 1.35,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _snapshot;
    final percent = item?.percent;
    final neutral = Colors.grey[300];

    final color = percent == null || item?.stale == true
        ? neutral
        : percent > 0
            ? const Color(0xFF38C172)
            : percent < 0
                ? Colors.red
                : neutral;

    final formatted = percent == null
        ? ''
        : '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%';

    final value = percent == null
        ? (_loading ? 'Checking…' : 'Unavailable')
        : item?.stale == true
            ? 'Last $formatted'
            : formatted;

    // Wrap naturally on narrow screens; never push into other wallet tabs.
    return ConstrainedBox(
      key: const Key('dgb24hFixedRow'),
      constraints: const BoxConstraints(minHeight: 44),
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => _details(item),
            child: Semantics(
              button: true,
              label: 'DGB 24-hour price change $value. Show source details.',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      '24hr:',
                      key: const Key('dgb24hTitle'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: neutral,
                      ),
                    ),
                    if (_loading && percent == null) ...[
                      SizedBox(
                        key: const Key('dgb24hLoading'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: neutral,
                        ),
                      ),
                    ],
                    Text(
                      value,
                      key: const Key('dgb24hChangeLabel'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Icon(
                      Icons.info_outline_rounded,
                      size: 19,
                      color: neutral,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
