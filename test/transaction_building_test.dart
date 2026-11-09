import 'dart:io';
import 'dart:typed_data';

import 'package:digicoinlib_flutter/digicoinlib_flutter.dart';
import 'package:digibyte/models/available_coins.dart';
import 'package:digibyte/models/hive/coin_wallet.dart';
import 'package:digibyte/models/hive/wallet_address.dart';
import 'package:digibyte/models/hive/wallet_transaction.dart';
import 'package:digibyte/models/hive/wallet_utxo.dart';
import 'package:digibyte/providers/encrypted_box_provider.dart';
import 'package:digibyte/providers/wallet_provider.dart';
import 'package:digibyte/tools/project_support.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class TestEncryptedBoxes extends EncryptedBoxProvider {
  final Uint8List testKey;

  TestEncryptedBoxes(this.testKey);

  @override
  Future<Box?> getGenericBox(String name) => Hive.openBox(
        name,
        encryptionCipher: HiveAesCipher(testKey),
      );

  @override
  Future<Box<CoinWallet>> getWalletBox() => Hive.openBox<CoinWallet>(
        'wallets',
        encryptionCipher: HiveAesCipher(testKey),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const identifier = 'digibyte';
  const mnemonic = 'abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon abandon abandon about';

  const txHash = '11223344556677889900aabbccddeeff'
      '00112233445566778899aabbccddeeff';

  const baseFunding = 200000000;

  final key = Uint8List.fromList(
    List<int>.generate(32, (i) => i + 1),
  );

  late Directory testDirectory;
  late WalletProvider wallet;
  late String ownAddress;

  int supportAmount() =>
      ProjectSupport.enabledFor('DGB') ? ProjectSupport.amount : 0;

  String recipientAddress(int index) {
    final privateKey = ECPrivateKey.fromHex(
      index.toRadixString(16).padLeft(64, '0'),
    );

    return P2PKHAddress.fromPublicKey(
      privateKey.pubkey,
      version: Network.mainnet.p2pkhPrefix,
    ).toString();
  }

  BigInt outputValue(Transaction tx, String address) {
    final targetScript = bytesToHex(
      Address.fromString(
        address,
        Network.mainnet,
      ).program.script.compiled,
    );

    return tx.outputs
        .where(
          (output) => bytesToHex(output.scriptPubKey) == targetScript,
        )
        .fold<BigInt>(
          BigInt.zero,
          (total, output) => total + output.value,
        );
  }

  void expectSigned(Transaction tx) {
    expect(tx.version, 1);
    expect(tx.complete, isTrue);

    for (var i = 0; i < tx.inputs.length; i++) {
      final input = tx.inputs[i] as P2PKHInput;
      final signature = input.insig!;

      final hash = LegacySignatureHasher(
        tx: tx,
        inputN: i,
        scriptCode: input.scriptCode,
        hashType: signature.hashType,
      ).hash;

      expect(
        signature.signature.verify(input.publicKey, hash),
        isTrue,
      );
    }
  }

  void expectConservation(
    Transaction tx,
    int inputValue,
    int fee,
  ) {
    final outputTotal = tx.outputs.fold<BigInt>(
      BigInt.zero,
      (total, output) => total + output.value,
    );

    expect(
      outputTotal + BigInt.from(fee),
      BigInt.from(inputValue),
      reason: 'Inputs must equal outputs plus the network fee',
    );
  }

  setUpAll(() async {
    await loadDigiCoinlib();

    testDirectory = Directory(
      'build/digibyte-transaction-regression-'
      '${DateTime.now().microsecondsSinceEpoch}',
    );

    await testDirectory.create(recursive: true);
    Hive.init(testDirectory.path);

    Hive.registerAdapter(CoinWalletAdapter());
    Hive.registerAdapter(WalletAddressAdapter());
    Hive.registerAdapter(WalletTransactionAdapter());
    Hive.registerAdapter(WalletUtxoAdapter());

    wallet = WalletProvider(TestEncryptedBoxes(key));

    await wallet.init();
    await wallet.createPhrase(mnemonic);

    await wallet.addWallet(
      name: identifier,
      title: 'DigiByte',
      letterCode: 'DGB',
      isImportedSeed: false,
      watchOnly: false,
    );

    await wallet.generateUnusedAddress(identifier);
    ownAddress = wallet.getUnusedAddress(identifier);

    expect(ownAddress, isNotEmpty);
  });

  setUp(() async {
    // Each test receives a fresh synthetic confirmed UTXO.
    // This never accesses an actual blockchain or wallet.
    await wallet.putUtxos(
      identifier: identifier,
      address: ownAddress,
      utxos: [
        {
          'tx_hash': txHash,
          'tx_pos': 0,
          'height': 200000,
          'value': baseFunding + supportAmount(),
        },
      ],
    );
  });

  tearDownAll(() async {
    await Hive.close();

    // Delete only the unique directory created by this test.
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test('DigiByte mainnet monetary and transaction parameters', () {
    final coin = AvailableCoins.getSpecificCoin(identifier);

    expect(coin.letterCode, 'DGB');
    expect(coin.fractions, 8);
    expect(coin.txVersion, 1);
    expect(
      AvailableCoins.getDecimalProduct(
        identifier: identifier,
      ),
      100000000,
    );
    expect(coin.minimumTxValue, 10000);
  });

  test('Confirmed UTXO updates spendable balance', () async {
    final utxos = await wallet.getWalletUtxos(identifier);
    final coinWallet = wallet.getSpecificCoinWallet(identifier);

    expect(utxos.length, 1);
    expect(utxos.single.address, ownAddress);
    expect(utxos.single.height, greaterThan(0));
    expect(
      coinWallet.balance,
      baseFunding + supportAmount(),
    );
  });

  test('Partial payment produces signed transaction and change', () async {
    final destination = recipientAddress(2);
    const payment = 25000000;

    final result = await wallet.buildTransaction(
      identifier: identifier,
      fee: 0,
      recipients: {destination: payment},
    );

    final tx = Transaction.fromHex(result.hex);

    expectSigned(tx);

    expect(result.id, tx.txid);
    expect(result.neededChange, isTrue);
    expect(result.fee, greaterThan(0));
    expect(result.totalAmount, payment);
    expect(result.recipients[destination], payment);

    expect(
      outputValue(tx, destination),
      BigInt.from(payment),
    );

    expect(
      outputValue(tx, ownAddress),
      greaterThan(BigInt.zero),
    );

    expect(result.projectSupport, supportAmount());

    if (supportAmount() > 0) {
      expect(
        outputValue(tx, ProjectSupport.address),
        BigInt.from(supportAmount()),
      );
    }

    expectConservation(
      tx,
      baseFunding + supportAmount(),
      result.fee,
    );
  });

  test('Send All uses full balance and reserves support plus fee', () async {
    final destination = recipientAddress(10);
    final balance = wallet.getSpecificCoinWallet(identifier).balance;

    final result = await wallet.buildTransaction(
      identifier: identifier,
      fee: 0,
      recipients: {destination: balance},
    );

    final tx = Transaction.fromHex(result.hex);
    expectSigned(tx);

    final expectedPayment = balance - supportAmount() - result.fee;

    expect(result.neededChange, isFalse);
    expect(result.feesHaveBeenDeductedFromRecipient, isTrue);
    expect(result.projectSupport, supportAmount());
    expect(result.recipients[destination], expectedPayment);
    expect(outputValue(tx, destination), BigInt.from(expectedPayment));
    expectConservation(tx, balance, result.fee);
  });

  test('Send-max deducts network fee from user payment', () async {
    final destination = recipientAddress(3);

    final result = await wallet.buildTransaction(
      identifier: identifier,
      fee: 0,
      recipients: {destination: baseFunding},
    );

    final tx = Transaction.fromHex(result.hex);

    expectSigned(tx);

    expect(result.neededChange, isFalse);
    expect(result.feesHaveBeenDeductedFromRecipient, isTrue);
    expect(result.fee, greaterThan(0));

    final expectedPayment = baseFunding - result.fee;

    expect(result.recipients[destination], expectedPayment);
    expect(result.totalAmount, expectedPayment);

    expect(
      outputValue(tx, destination),
      BigInt.from(expectedPayment),
    );

    expect(result.projectSupport, supportAmount());

    if (supportAmount() > 0) {
      expect(
        outputValue(tx, ProjectSupport.address),
        BigInt.from(supportAmount()),
      );
    }

    expectConservation(
      tx,
      baseFunding + supportAmount(),
      result.fee,
    );
  });

  test('Multiple recipients and OP_RETURN are preserved', () async {
    final first = recipientAddress(4);
    final second = recipientAddress(5);
    final third = recipientAddress(6);

    const recipients = <int>[9000000, 8000000, 7000000];
    const message = 'DigiByte regression';

    final result = await wallet.buildTransaction(
      identifier: identifier,
      fee: 0,
      recipients: {
        first: recipients[0],
        second: recipients[1],
        third: recipients[2],
      },
      opReturn: message,
    );

    final tx = Transaction.fromHex(result.hex);

    expectSigned(tx);

    expect(result.recipients.length, 3);
    expect(result.totalAmount, 24000000);

    expect(
      outputValue(tx, first),
      BigInt.from(recipients[0]),
    );
    expect(
      outputValue(tx, second),
      BigInt.from(recipients[1]),
    );
    expect(
      outputValue(tx, third),
      BigInt.from(recipients[2]),
    );

    final opReturnOutputs = tx.outputs
        .where(
          (output) =>
              output.scriptPubKey.isNotEmpty &&
              output.scriptPubKey.first == 0x6a,
        )
        .toList();

    expect(opReturnOutputs.length, 1);
    expect(opReturnOutputs.single.value, BigInt.zero);
    expect(
      bytesToHex(opReturnOutputs.single.scriptPubKey),
      contains('44696769427974652072656772657373696f6e'),
    );

    expect(result.opReturn, message);

    expectConservation(
      tx,
      baseFunding + supportAmount(),
      result.fee,
    );
  });

  test('Overspending confirmed funds is rejected', () async {
    final destination = recipientAddress(7);

    await expectLater(
      wallet.buildTransaction(
        identifier: identifier,
        fee: 0,
        recipients: {
          destination: baseFunding + supportAmount() + 1,
        },
      ),
      throwsA(
        equals('tx amount greater wallet balance'),
      ),
    );
  });

  test('Unconfirmed UTXOs are not spendable balance', () async {
    await wallet.putUtxos(
      identifier: identifier,
      address: ownAddress,
      utxos: [
        {
          'tx_hash': txHash,
          'tx_pos': 0,
          'height': 0,
          'value': baseFunding,
        },
      ],
    );

    final coinWallet = wallet.getSpecificCoinWallet(identifier);

    expect(coinWallet.balance, 0);
    expect(coinWallet.unconfirmedBalance, baseFunding);

    await expectLater(
      wallet.buildTransaction(
        identifier: identifier,
        fee: 0,
        recipients: {
          recipientAddress(8): 1000000,
        },
      ),
      throwsA(
        equals('tx amount greater wallet balance'),
      ),
    );
  });
}
