import 'package:hive/hive.dart';
part 'wallet_transaction.g.dart';

@HiveType(typeId: 3)
class WalletTransaction extends HiveObject {
  @HiveField(0)
  final String txid;
  @HiveField(1, defaultValue: 0)
  int timestamp;
  @HiveField(2)
  final int value;
  @HiveField(3)
  final int fee;
  @HiveField(4)
  final String address;
  @HiveField(5)
  final String direction;
  @HiveField(6)
  int confirmations = 0;
  @HiveField(7)
  bool broadCasted = true;
  @HiveField(8)
  String broadcastHex = '';
  @HiveField(9, defaultValue: '')
  String opReturn = '';
  @HiveField(10, defaultValue: {})
  Map<String, int> recipients = {};

  @HiveField(11, defaultValue: 0)
  int startingBalance = 0;

  @HiveField(12, defaultValue: 0)
  int endingBalance = 0;

  @HiveField(13, defaultValue: 0.0)
  double fiatRateAtTx = 0.0;

  @HiveField(14, defaultValue: '')
  String fiatCodeAtTx = '';

  @HiveField(15, defaultValue: 0)
  int fiatSnapshotTimestamp = 0;

  WalletTransaction({
    required this.txid,
    required this.timestamp,
    required this.value,
    required this.fee,
    required this.address,
    required this.recipients,
    required this.direction,
    required this.broadCasted,
    required this.broadcastHex,
    required this.confirmations,
    required this.opReturn,
    this.startingBalance = 0,
    this.endingBalance = 0,
    this.fiatRateAtTx = 0.0,
    this.fiatCodeAtTx = '',
    this.fiatSnapshotTimestamp = 0,
  });

  set newTimestamp(int newTime) {
    timestamp = newTime;
  }

  set newConfirmations(int newConfirmations) {
    confirmations = newConfirmations;
  }

  set newBroadcasted(bool newBroadcasted) {
    broadCasted = newBroadcasted;
  }

  set newOpReturn(String newOpReturn) {
    opReturn = newOpReturn;
  }

  set newStartingBalance(int newStartingBalance) {
    startingBalance = newStartingBalance;
  }

  set newEndingBalance(int newEndingBalance) {
    endingBalance = newEndingBalance;
  }

  set newFiatRateAtTx(double newFiatRateAtTx) {
    fiatRateAtTx = newFiatRateAtTx;
  }

  set newFiatCodeAtTx(String newFiatCodeAtTx) {
    fiatCodeAtTx = newFiatCodeAtTx;
  }

  set newFiatSnapshotTimestamp(int newFiatSnapshotTimestamp) {
    fiatSnapshotTimestamp = newFiatSnapshotTimestamp;
  }

  void resetBroadcastHex() {
    broadcastHex = '';
  }
}
