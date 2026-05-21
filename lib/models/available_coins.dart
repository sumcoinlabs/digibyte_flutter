import 'dart:math';

import 'package:digicoinlib_flutter/digicoinlib_flutter.dart';

import 'coin.dart';

class AvailableCoins {
  static final Map<String, Coin> _availableCoinList = {
    'digibyte': Coin(
      name: 'digibyte',
      displayName: 'DigiByte',
      uriCode: 'digibyte',
      letterCode: 'DGB',
      iconPath: 'assets/icon/dgb-icon-48.png',
      iconPathTransparent: 'assets/icon/dgb-icon-white-48.png',
      networkType: Network.mainnet,
      opreturnSize: 256,
      fractions: 8,
      minimumTxValue: 10000,
      fixedFee: true,
      fixedFeePerKb: 0.01,
      explorerUrl: 'https://chainz.cryptoid.info/dgb/tx.dws?',
      genesisHash:
          '7497ea1b465eb39f1c8f507bc877078fe016d6fcb6dfad3a64c98dcc6e1e8496',
      txVersion: 1,
      electrumRequiredProtocol: 1.4,
      electrumServers: [
    //  'ssl://electrum1.cipig.net:20059',
    //  'ssl://electrum2.cipig.net:20059',
    //  'ssl://electrum3.cipig.net:20059',
      'wss://electrum1.cipig.net:30059',
      'wss://electrum2.cipig.net:30059',
      'wss://electrum3.cipig.net:30059',
      ],
      marismaServers: [
        ('marisma.ppc.lol', 8443),
      ],
    ),
  /*  'peercoinTestnet': Coin(
      name: 'peercoinTestnet',
      displayName: 'DigiByte Testnet',
      uriCode: 'digibyte',
      letterCode: 'tDGB',
      iconPath: 'assets/icon/dgb-icon-48-grey.png',
      iconPathTransparent: 'assets/icon/dgb-icon-48-grey.png',
      networkType: Network.testnet,
      opreturnSize: 256,
      fixedFee: true,
      fractions: 6,
      minimumTxValue: 10000,
      fixedFeePerKb: 0.01,
      explorerUrl: 'https://tblockbook.digibyte.net',
      genesisHash:
          '00000001f757bb737f6596503e17cd17b0658ce630cc727c0cca81aec47c9f06',
      txVersion: 1,
      electrumRequiredProtocol: 1.4,
      electrumServers: [
        'wss://testnet-electrum.peercoinexplorer.net:50009',
        'wss://allingas.peercoinexplorer.net:50009',
      ],
      marismaServers: [
        ('test-marisma.ppc.lol', 2096),
      ],
    ), */
  };

  static Map<String, Coin> get availableCoins {
    return _availableCoinList;
  }

  static Coin getSpecificCoin(String identifier) {
    final coin = identifier.split('_').first;
    if (_availableCoinList.containsKey(coin)) {
      return _availableCoinList[coin]!;
    } else {
      throw Exception('Coin not found');
    }
  }

  static int getDecimalProduct({
    required String identifier,
  }) {
    return pow(
      10,
      getSpecificCoin(identifier).fractions,
    ).toInt();
  }
}
