import 'dart:io';
import 'dart:typed_data';

import 'package:digicoinlib_flutter/digicoinlib_flutter.dart';
import 'package:digibyte/models/hive/coin_wallet.dart';
import 'package:digibyte/models/hive/wallet_address.dart';
import 'package:digibyte/models/hive/wallet_transaction.dart';
import 'package:digibyte/models/hive/wallet_utxo.dart';
import 'package:digibyte/providers/encrypted_box_provider.dart';
import 'package:digibyte/providers/wallet_provider.dart';
import 'package:digibyte/tools/project_support.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class SyntheticEncryptedBoxes extends EncryptedBoxProvider {
  final Uint8List testKey;

  SyntheticEncryptedBoxes(this.testKey);

  @override
  Future<Box?> getGenericBox(String name) =>
      Hive.openBox(name, encryptionCipher: HiveAesCipher(testKey));

  @override
  Future<Box<CoinWallet>> getWalletBox() =>
      Hive.openBox<CoinWallet>(
        'wallets',
        encryptionCipher: HiveAesCipher(testKey),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mnemonic =
      'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon about';

  const identifier = 'digibyte';
  const utxoHash =
      '000102030405060708090a0b0c0d0e0f'
      '101112131415161718191a1b1c1d1e1f';

  final testKey = Uint8List.fromList(
    List<int>.generate(32, (i) => i + 1),
  );

  late Directory testDirectory;
  late WalletProvider wallet;
  late String ownAddress;
  late int fundedValue;

  setUpAll(() async {
    await loadDigiCoinlib();

    testDirectory = Directory(
      'build/wallet-provider-regression-'
      '${DateTime.now().microsecondsSinceEpoch}',
    );

    await testDirectory.create(recursive: true);
    Hive.init(testDirectory.path);

    Hive.registerAdapter(CoinWalletAdapter());
    Hive.registerAdapter(WalletAddressAdapter());
    Hive.registerAdapter(WalletTransactionAdapter());
    Hive.registerAdapter(WalletUtxoAdapter());

    wallet = WalletProvider(SyntheticEncryptedBoxes(testKey));
    await wallet.init();
    await wallet.createPhrase(mnemonic);

    await wallet.addWallet(
      name: identifier,
      title: 'DigiByte',
      letterCode: 'DGB',
      isImportedSeed: false,
      watchOnly: false,
    );
  });

  tearDownAll(() async {
    await Hive.close();

    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test('Seed-derived address and WIF match', () async {
    await wallet.generateUnusedAddress(identifier);

    ownAddress = wallet.getUnusedAddress(identifier);
    final network = Network.mainnet;

    expect(
      Address.fromString(ownAddress, network),
      isA<P2PKHAddress>(),
    );

    final wif = await wallet.getWif(
      identifier: identifier,
      address: ownAddress,
    );

    final derivedAddress = P2PKHAddress.fromPublicKey(
      WIF.fromString(wif).privkey.pubkey,
      version: network.p2pkhPrefix,
    ).toString();

    expect(derivedAddress, ownAddress);

    final addresses = await wallet.getWalletAddresses(identifier);
    expect(addresses.length, 1);
    expect(addresses.single.address, ownAddress);
  });

  test('Construct and sign a funded DigiByte transaction', () async {
    const sendValue = 1000000;

    final supportEnabled = ProjectSupport.enabledFor('DGB');
    final expectedSupport =
        supportEnabled ? ProjectSupport.amount : 0;

    expect(expectedSupport, greaterThanOrEqualTo(0));

    // Synthetic funding covers the payment, optional contribution,
    // transaction fee, and a substantial change output.
    final inputValue = sendValue + expectedSupport + 5000000;
    fundedValue = inputValue;

    await wallet.putUtxos(
      identifier: identifier,
      address: ownAddress,
      utxos: [
        {
          'tx_hash': utxoHash,
          'tx_pos': 0,
          'height': 200000,
          'value': inputValue,
        },
      ],
    );

    expect(
      wallet.getSpecificCoinWallet(identifier).balance,
      inputValue,
    );

    final recipientKey = ECPrivateKey.fromHex(
      '00000000000000000000000000000000'
      '00000000000000000000000000000002',
    );

    final recipient = P2PKHAddress.fromPublicKey(
      recipientKey.pubkey,
      version: Network.mainnet.p2pkhPrefix,
    );

    final result = await wallet.buildTransaction(
      identifier: identifier,
      fee: 0,
      recipients: {recipient.toString(): sendValue},
    );

    final tx = Transaction.fromHex(result.hex);

    expect(tx.version, 1);
    expect(tx.complete, isTrue);
    expect(tx.inputs.length, 1);
    expect(result.id, tx.txid);
    expect(result.neededChange, isTrue);
    expect(result.totalAmount, sendValue);
    expect(result.projectSupport, expectedSupport);
    expect(
      result.projectSupportAddress,
      supportEnabled ? ProjectSupport.address : '',
    );
    expect(result.recipients[recipient.toString()], sendValue);

    if (supportEnabled && expectedSupport > 0) {
      final supportAddress = Address.fromString(
        ProjectSupport.address,
        Network.mainnet,
      );

      final supportScript = bytesToHex(
        supportAddress.program.script.compiled,
      );

      final supportOutputs = tx.outputs.where(
        (output) =>
            bytesToHex(output.scriptPubKey) == supportScript,
      ).toList();

      expect(supportOutputs.length, 1);
      expect(
        supportOutputs.single.value,
        BigInt.from(expectedSupport),
      );
    }
    expect(result.fee, greaterThan(0));

    final recipientScript = bytesToHex(
      recipient.program.script.compiled,
    );

    final recipientOutputs = tx.outputs.where(
      (output) =>
          bytesToHex(output.scriptPubKey) == recipientScript,
    ).toList();

    expect(recipientOutputs.length, 1);
    expect(recipientOutputs.single.value, BigInt.from(sendValue));

    // Every satoshi must be accounted for:
    // recipients + change + optional project support + fee.
    final outputTotal = tx.outputs.fold<BigInt>(
      BigInt.zero,
      (total, output) => total + output.value,
    );

    expect(
      outputTotal + BigInt.from(result.fee),
      BigInt.from(inputValue),
    );

    final signedInput = tx.inputs.single as P2PKHInput;
    final signature = signedInput.insig!;

    final signatureHash = LegacySignatureHasher(
      tx: tx,
      inputN: 0,
      scriptCode: signedInput.scriptCode,
      hashType: signature.hashType,
    ).hash;

    expect(
      signature.signature.verify(
        signedInput.publicKey,
        signatureHash,
      ),
      isTrue,
    );

    // Building a transaction must not broadcast or spend funds.
    expect(
      wallet.getSpecificCoinWallet(identifier).balance,
      inputValue,
    );
  });

  test('Encrypted wallet survives closing and reopening Hive', () async {
    await Hive.close();

    final reopened = WalletProvider(
      SyntheticEncryptedBoxes(testKey),
    );

    await reopened.init();

    expect(await reopened.seedPhrase, mnemonic);

    final restoredWallet =
        reopened.getSpecificCoinWallet(identifier);

    expect(restoredWallet.addresses.single.address, ownAddress);
    expect(restoredWallet.utxos.single.value, fundedValue);
    expect(restoredWallet.balance, fundedValue);

    await reopened.generateUnusedAddress(identifier);

    expect(
      reopened.getUnusedAddress(identifier),
      ownAddress,
    );
  });
}
