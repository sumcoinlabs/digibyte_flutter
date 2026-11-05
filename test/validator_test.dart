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
        validateAddress('DUSSTNhY54ydZoA6H8ybzy2LA1HQvYpS1G', network) == true,
      );
      assert(
        validateAddress('DUSSTNhY54ydZoA6H8ybzy2LA1HQvYpS1H', network) == false,
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
