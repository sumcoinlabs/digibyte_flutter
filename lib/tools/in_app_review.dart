import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pure, deterministic policy: no wallet data or StoreKit state is inspected.
class ReviewPromptPolicy {
  static const cooldown = Duration(days: 45);

  static bool eligible({
    required DateTime now,
    required DateTime firstSeen,
    required int sessions,
    required bool returningUser,
    required String version,
    required String? previousVersion,
    required DateTime? lastAttempt,
    required List<DateTime> attempts,
  }) {
    if (sessions < (returningUser ? 2 : 4)) return false;
    if (now.difference(firstSeen) < Duration(days: returningUser ? 1 : 3)) {
      return false;
    }
    if (previousVersion == version) return false;
    if (lastAttempt != null &&
        (now.isBefore(lastAttempt) || now.difference(lastAttempt) < cooldown)) {
      return false;
    }
    final attemptsInYear = attempts.where((date) {
      final elapsed = now.difference(date);
      return !elapsed.isNegative && elapsed < const Duration(days: 365);
    }).length;
    return attemptsInYear < 4;
  }
}

/// Runs only on an initialized, visible wallet screen. The old startup entry
/// point remains as a no-op so the private, ignored main.dart needs no edits.
class InAppReviewService {
  InAppReviewService._internal();
  // Public constructor retained because private main.dart calls it directly.
  factory InAppReviewService() => instance;
  static final InAppReviewService instance = InAppReviewService._internal();

  static const _prefix = 'review_v2_';
  bool _sessionRegistered = false;
  bool _requestInProgress = false;

  /// Compatibility with the existing *private* main.dart. That file owns the
  /// general appOpens counter; this method intentionally does nothing.
  Future<void> incrementAppOpens() async {}

  Future<void> registerWalletSession() async {
    if (_sessionRegistered || kIsWeb) return;
    _sessionRegistered = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!prefs.containsKey('${_prefix}first_seen')) {
        await prefs.setInt('${_prefix}first_seen', now);
        final returningUser = (prefs.getBool('reviewSubmitted') ?? false) ||
            (prefs.getInt('appOpens') ?? 0) >= 8;
        await prefs.setBool('${_prefix}returning', returningUser);
      }
      final lastSession = prefs.getInt('${_prefix}last_session') ?? 0;
      if (now - lastSession >= const Duration(minutes: 20).inMilliseconds) {
        final sessions = prefs.getInt('${_prefix}sessions') ?? 0;
        await prefs.setInt('${_prefix}sessions', sessions + 1);
        await prefs.setInt('${_prefix}last_session', now);
      }
    } catch (_) {
      // Review functionality must never prevent the wallet from working.
      _sessionRegistered = false;
    }
  }

  Future<void> maybeRequestReview() async {
    // The public Android APK is not installed from Play, so do not invoke the
    // Play review API. Review requests are only enabled for App Store iOS.
    if (kIsWeb ||
        !Platform.isIOS ||
        !_sessionRegistered ||
        _requestInProgress) {
      return;
    }
    _requestInProgress = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final package = await PackageInfo.fromPlatform();
      final firstSeen = prefs.getInt('${_prefix}first_seen');
      if (firstSeen == null) return;
      final attempts = (prefs.getStringList('${_prefix}attempts') ?? <String>[])
          .map(DateTime.tryParse)
          .whereType<DateTime>()
          .toList();
      final previousAttempt = prefs.getInt('${_prefix}last_attempt');
      final lastAttempt = previousAttempt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(previousAttempt);
      final eligible = ReviewPromptPolicy.eligible(
        now: now,
        firstSeen: DateTime.fromMillisecondsSinceEpoch(firstSeen),
        sessions: prefs.getInt('${_prefix}sessions') ?? 0,
        returningUser: prefs.getBool('${_prefix}returning') ?? false,
        version: package.version,
        previousVersion: prefs.getString('${_prefix}last_version'),
        lastAttempt: lastAttempt,
        attempts: attempts,
      );
      if (!eligible) return;
      final reviewer = InAppReview.instance;
      if (!await reviewer.isAvailable()) return;

      // Record an *attempt*, never claim that a review was submitted.
      // Apple chooses whether a request appears; it does not report the result.
      final recent = attempts
          .where((date) {
            final elapsed = now.difference(date);
            return !elapsed.isNegative && elapsed < const Duration(days: 365);
          })
          .map((date) => date.toIso8601String())
          .toList();
      recent.add(now.toIso8601String());
      await prefs.setStringList('${_prefix}attempts', recent);
      await prefs.setInt('${_prefix}last_attempt', now.millisecondsSinceEpoch);
      await prefs.setString('${_prefix}last_version', package.version);
      await reviewer.requestReview();
    } catch (_) {
      // A suppressed or unavailable prompt must never interrupt wallet use.
    } finally {
      _requestInProgress = false;
    }
  }

  /// Persistent user-initiated review link, separate from native prompt quota.
  Future<bool> openAppStoreReview() async {
    if (kIsWeb || !Platform.isIOS) return false;
    final url = Uri.parse(
      'https://apps.apple.com/app/id6481703766?action=write-review',
    );
    try {
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (opened) {
        final prefs = await SharedPreferences.getInstance();
        final package = await PackageInfo.fromPlatform();
        final now = DateTime.now();
        await prefs.setInt(
            '${_prefix}last_attempt', now.millisecondsSinceEpoch);
        await prefs.setString('${_prefix}last_version', package.version);
        // This is not an in-app prompt attempt; don't count it toward our
        // automatic 4-per-year attempt budget.
      }
      return opened;
    } catch (_) {
      return false;
    }
  }
}
