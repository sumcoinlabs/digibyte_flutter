import 'package:digicoinlib_flutter/digicoinlib_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digibyte/models/available_coins.dart';
import 'package:digibyte/tools/validators.dart';

void main() async {
  //init coinlib
  await loadDigiCoinlib();

  group('validators', () {
    final network = AvailableCoins.getSpecificCoin('digibyte').networkType;
    test('validateAddress', () {
      assert(
        validateAddress('PXDR4KZn2WdTocNx1GPJXR96PfzZBvWqKQ', network) == true,
      );
      assert(
        validateAddress('PXDR4KZn2WdTocNx1GPJXR96PfzZBvWqKq', network) == false,
      );
    });

    test('validateWIFPrivKey', () {
      assert(
        validateWIFPrivKey(
              'UBhubKxzjdkdPEwMX83nKS1RNgJCWBXFoE7pDrXaQJA3MjeFL8cf',
            ) ==
            true,
      );
      assert(
        validateWIFPrivKey(
              'UBhubKxzjdkdPEwMX83nKS1RNgJCWBXFoE7pDrXaQJA3MjeFL8cF',
            ) ==
            false,
      );
    });
  });
}
