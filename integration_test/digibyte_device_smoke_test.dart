import 'package:digicoinlib_flutter/digicoinlib_flutter.dart';
import 'package:digibyte/models/available_coins.dart';
import 'package:digibyte/tools/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DigiByte native signing and Android rendering',
      (tester) async {
    await loadDigiCoinlib();

    final coin = AvailableCoins.getSpecificCoin('digibyte');

    expect(coin.networkType.p2pkhPrefix, 30);
    expect(coin.networkType.p2shPrefix, 63);
    expect(coin.networkType.wifPrefix, 128);
    expect(coin.networkType.bech32Hrp, 'dgb');
    expect(coin.fractions, 8);

    final key = ECPrivateKey.fromHex(
      '00000000000000000000000000000000'
      '00000000000000000000000000000001',
    );

    final hash = hexToBytes(
      '000102030405060708090a0b0c0d0e0f'
      '101112131415161718191a1b1c1d1e1f',
    );

    final signature = ECDSASignature.sign(
      key,
      hash,
      forceLowR: true,
    );

    expect(signature.verify(key.pubkey, hash), isTrue);

    expect(
      bytesToHex(signature.compact),
      '0eda3be316b7d47901bc6a2bfc1b95cf6c408129a564d6b75963451e16fa155'
      '025077334a5bf937fcf3242cec81506deea34e26e65892bda896533c4e50e9360',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: MyTheme.getTheme(ThemeMode.light),
        home: const Scaffold(
          body: Center(
            child: Text('DigiByte Android Device Test'),
          ),
        ),
      ),
    );

    expect(
      find.text('DigiByte Android Device Test'),
      findsOneWidget,
    );
  });
}
