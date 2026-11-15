import 'package:digibyte/tools/in_app_review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 15);
  final old = now.subtract(const Duration(days: 5));

  bool eligible({
    DateTime? firstSeen,
    int sessions = 4,
    bool returning = false,
    String? lastVersion,
    DateTime? lastAttempt,
    List<DateTime> attempts = const [],
  }) =>
      ReviewPromptPolicy.eligible(
        now: now,
        firstSeen: firstSeen ?? old,
        sessions: sessions,
        returningUser: returning,
        version: '0.1.7',
        previousVersion: lastVersion,
        lastAttempt: lastAttempt,
        attempts: attempts,
      );

  test('new users need three days and four sessions', () {
    expect(eligible(firstSeen: now.subtract(const Duration(days: 2))), isFalse);
    expect(eligible(sessions: 3), isFalse);
    expect(eligible(), isTrue);
  });

  test('existing users need a day and two sessions', () {
    expect(eligible(returning: true, sessions: 1), isFalse);
    expect(
        eligible(
          returning: true,
          sessions: 2,
          firstSeen: now.subtract(const Duration(hours: 20)),
        ),
        isFalse);
    expect(eligible(returning: true, sessions: 2), isTrue);
  });

  test('never repeat an automatic request in the same app version', () {
    expect(eligible(lastVersion: '0.1.7'), isFalse);
    expect(eligible(lastVersion: '0.1.6'), isTrue);
  });

  test('enforce minimum forty-five day cooldown', () {
    expect(
        eligible(lastAttempt: now.subtract(const Duration(days: 44))), isFalse);
    expect(
        eligible(lastAttempt: now.subtract(const Duration(days: 45))), isTrue);
    expect(eligible(lastAttempt: now.add(const Duration(days: 1))), isFalse);
  });

  test('never exceed four automatic requests in a rolling year', () {
    final attempts =
        List.generate(4, (n) => now.subtract(Duration(days: 60 + n * 60)));
    expect(eligible(attempts: attempts), isFalse);
    expect(
        eligible(attempts: [
          ...attempts.take(3),
          now.subtract(const Duration(days: 366))
        ]),
        isTrue);
  });
}
