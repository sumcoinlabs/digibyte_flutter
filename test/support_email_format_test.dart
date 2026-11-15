import 'package:digibyte/tools/support_email.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('short support email includes automatically collected diagnostics', () {
    final text = WalletSupportEmail.bodyForDetails(
      appVersion: '0.1.6 (build 16)',
      device: 'iPhone 12 Pro Max',
      operatingSystem: 'iOS 18.1',
    );
    expect(text, contains('iPhone 12 Pro Max'));
    expect(text, contains('iOS 18.1'));
    expect(text, contains('0.1.6 (build 16)'));
    expect(text, contains('screenshot'));
    expect(text, contains('recovery phrase'));
    expect(text, isNot(contains('Negative app store reviews')));
    expect(text.length, lessThan(750));
  });
}
