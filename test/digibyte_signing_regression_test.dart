import 'package:digicoinlib_flutter/digicoinlib_flutter.dart';
import 'package:digibyte/models/available_coins.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(loadDigiCoinlib);

  test('DigiByte mainnet configuration', () {
    final coin = AvailableCoins.getSpecificCoin('digibyte');

    expect(coin.networkType.p2pkhPrefix, 30);
    expect(coin.networkType.p2shPrefix, 63);
    expect(coin.networkType.wifPrefix, 128);
    expect(coin.networkType.bech32Hrp, 'dgb');
    expect(coin.txVersion, 1);
    expect(coin.fractions, 8);
  });

  test('Known secp256k1 ECDSA signature vector', () {
    final key = ECPrivateKey.fromHex(
      '0000000000000000000000000000000000000000000000000000000000000001',
    );

    final hash = hexToBytes(
      '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f',
    );

    final signature = ECDSASignature.sign(
      key,
      hash,
      forceLowR: true,
    );

    expect(
      bytesToHex(signature.compact),
      '0eda3be316b7d47901bc6a2bfc1b95cf6c408129a564d6b75963451e16fa155'
      '025077334a5bf937fcf3242cec81506deea34e26e65892bda896533c4e50e9360',
    );

    expect(signature.verify(key.pubkey, hash), isTrue);
  });

  test('DigiByte transaction signing and signature verification', () {
    final key = ECPrivateKey.fromHex(
      '0000000000000000000000000000000000000000000000000000000000000001',
    );

    final coin = AvailableCoins.getSpecificCoin('digibyte');

    final address = P2PKHAddress.fromPublicKey(
      key.pubkey,
      version: coin.networkType.p2pkhPrefix,
    );

    expect(
      Address.fromString(address.toString(), coin.networkType),
      isA<P2PKHAddress>(),
    );

    final input = P2PKHInput(
      prevOut: OutPoint.fromHex(
        '32d1f1cf811456c6da4ef9e1cb7f8bb80c4c5e9f2d2c3d743f2b68a9c6857823',
        1,
      ),
      publicKey: key.pubkey,
    );

    final unsigned = Transaction(
      version: coin.txVersion,
      inputs: [input],
      outputs: [
        Output.fromAddress(BigInt.from(2000000), address),
      ],
    );

    expect(unsigned.complete, isFalse);

    final signed = unsigned.sign(inputN: 0, key: key);

    expect(signed.complete, isTrue);
    expect(signed.version, 1);
    expect(signed.toHex().startsWith('01000000'), isTrue);

    final signature = (signed.inputs.single as P2PKHInput).insig!;

    final originalHash = LegacySignatureHasher(
      tx: unsigned,
      inputN: 0,
      scriptCode: input.scriptCode,
      hashType: signature.hashType,
    ).hash;

    expect(signature.signature.verify(key.pubkey, originalHash), isTrue);

    final altered = Transaction(
      version: coin.txVersion,
      inputs: [input],
      outputs: [
        Output.fromAddress(BigInt.from(1900000), address),
      ],
    );

    final alteredHash = LegacySignatureHasher(
      tx: altered,
      inputN: 0,
      scriptCode: input.scriptCode,
      hashType: signature.hashType,
    ).hash;

    expect(signature.signature.verify(key.pubkey, alteredHash), isFalse);

    final decoded = Transaction.fromHex(signed.toHex());

    expect(decoded.toHex(), signed.toHex());
    expect(decoded.txid, signed.txid);
    expect(decoded.complete, isTrue);
  });
}
