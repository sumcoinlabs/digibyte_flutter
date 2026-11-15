import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pure, deterministic policy: no wallet data or StoreKit state is inspected.
class ReviewPromptPolicy {
  static const cooldown = Duration(days: 45);
  // A user who deliberately opens the App Store gets a respectful quiet period.
  // This never consumes an automatic request or marks a review as submitted.
  static const manualOpenCooldown = Duration(days: 30);

  static bool matchesAutomaticAttempt(DateTime? recorded, DateTime? automatic) {
    if (recorded == null || automatic == null) return false;
    return recorded.difference(automatic).inMilliseconds.abs() <= 2000;
  }

  static bool eligible({
    required DateTime now,
    required DateTime firstSeen,
    required int sessions,
    required bool returningUser,
    required String version,
    required String? previousVersion,
    required DateTime? lastAttempt,
    DateTime? lastManualOpen,
    required List<DateTime> attempts,
  }) {
    if (sessions < (returningUser ? 2 : 4)) return false;
    if (now.difference(firstSeen) < Duration(days: returningUser ? 1 : 3)) {
      return false;
    }
    if (previousVersion == version) return false;
    if (lastManualOpen != null &&
        (now.isBefore(lastManualOpen) ||
            now.difference(lastManualOpen) < manualOpenCooldown)) {
      return false;
    }
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
        final returningUser =
            (prefs.getBool('reviewSubmitted') ?? false) ||
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
      // Automatic requests are recorded in `attempts`. Older builds also
      // stored *manual App Store visits* in last_attempt / last_version,
      // so use the list as the source of truth and recover any manual visit.
      final lastAutomaticAttempt = attempts.isEmpty
          ? null
          : attempts.reduce((a, b) => a.isAfter(b) ? a : b);
      final previousAttempt = prefs.getInt('${_prefix}last_attempt');
      final recordedAttempt = previousAttempt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(previousAttempt);
      final recordedWasAutomatic = ReviewPromptPolicy.matchesAutomaticAttempt(
        recordedAttempt,
        lastAutomaticAttempt,
      );
      final previousAutomaticVersion =
          prefs.getString('${_prefix}last_auto_version') ??
          (recordedWasAutomatic
              ? prefs.getString('${_prefix}last_version')
              : null);
      final previousManualOpen = prefs.getInt('${_prefix}last_manual_open');
      DateTime? lastManualOpen = previousManualOpen == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(previousManualOpen);
      if (recordedAttempt != null &&
          (lastAutomaticAttempt == null ||
              recordedAttempt.isAfter(
                lastAutomaticAttempt.add(const Duration(seconds: 2)),
              )) &&
          (lastManualOpen == null || recordedAttempt.isAfter(lastManualOpen))) {
        lastManualOpen = recordedAttempt;
      }
      final eligible = ReviewPromptPolicy.eligible(
        now: now,
        firstSeen: DateTime.fromMillisecondsSinceEpoch(firstSeen),
        sessions: prefs.getInt('${_prefix}sessions') ?? 0,
        returningUser: prefs.getBool('${_prefix}returning') ?? false,
        version: package.version,
        previousVersion: previousAutomaticVersion,
        lastAttempt: lastAutomaticAttempt,
        lastManualOpen: lastManualOpen,
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
      await prefs.setString('${_prefix}last_auto_version', package.version);
      await reviewer.requestReview();
    } catch (_) {
      // A suppressed or unavailable prompt must never interrupt wallet use.
    } finally {
      _requestInProgress = false;
    }
  }

  /// Development-only preview of Apple's native review prompt on a real iPhone.
  /// This bypasses our policy, never records an attempt, and can be suppressed by iOS.
  /// It is impossible to know whether StoreKit actually displayed the dialog.
  Future<bool> requestDebugReview() async {
    if (!kDebugMode || kIsWeb || !Platform.isIOS) return false;
    try {
      final reviewer = InAppReview.instance;
      if (!await reviewer.isAvailable()) return false;
      await reviewer.requestReview();
      return true;
    } catch (_) {
      return false;
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
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(
            '${_prefix}last_manual_open',
            DateTime.now().millisecondsSinceEpoch,
          );
        } catch (_) {
          // The App Store opened successfully even if preference storage fails.
        }
      }
      return opened;
    } catch (_) {
      return false;
    }
  }
}
