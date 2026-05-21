import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';

import '../providers/app_settings_provider.dart';
import 'logger_wrapper.dart';

class PriceTicker {
  static bool _isUpdating = false;

  static Future<Map<String, dynamic>> getDataFromTicker() async {
    final client = RetryClient(http.Client());
    var url = Uri.parse('https://worker-ticker.totality.workers.dev');

    try {
      var response = await client.read(url);
      final Map<String, dynamic> data = json.decode(response);
      return data;
    } catch (err) {
      LoggerWrapper.logError(
        'PriceTicker',
        'getDataFromTicker',
        err.toString(),
      );
      rethrow;
    } finally {
      client.close();
    }
  }

  static Map currencySymbols = {
    'AED': 'د.إ',
    'AFN': '؋',
    'ALL': 'Lek',
    'AMD': '֏',
    'ANG': 'ƒ',
    'AOA': 'Kz',
    'ARS': '\$',
    'AUD': 'A\$',
    'AWG': 'ƒ',
    'AZN': '₼',
    'BAM': 'KM',
    'BBD': '\$',
    'BDT': '৳',
    'BGN': 'лв',
    'BHD': 'ب.د',
    'BIF': 'FBu',
    'BMD': '\$',
    'BND': '\$',
    'BOB': 'Bs.',
    'BRL': 'R\$',
    'BSD': '\$',
    'BTN': 'Nu.',
    'BWP': 'P',
    'BYN': 'Br',
    'BZD': 'BZ\$',
    'CAD': '\$',
    'CDF': 'FC',
    'CHF': 'Fr.',
    'CLF': 'UF',
    'CLP': '\$',
    'CNY': '¥',
    'COP': '\$',
    'CRC': '₡',
    'CUP': '\$',
    'CVE': 'Esc',
    'CZK': 'Kč',
    'DJF': 'Fdj',
    'DKK': 'Kr.',
    'DOP': 'RD\$',
    'DZD': 'د.ج',
    'EGP': 'ج.م',
    'ERN': 'Nfk',
    'ETB': 'ብር',
    'EUR': '€',
    'FJD': 'FJ\$',
    'GBP': '£',
    'GEL': '₾',
    'GHS': '₵',
    'GIP': '£',
    'GMD': 'D',
    'GNF': 'FG',
    'GTQ': 'Q',
    'GYD': '\$',
    'HKD': '\$',
    'HNL': 'L',
    'HTG': 'G',
    'HUF': 'Ft',
    'IDR': 'Rp',
    'ILS': '₪',
    'INR': '₹',
    'IQD': 'ع.د',
    'IRR': '﷼',
    'ISK': 'kr',
    'JMD': '\$',
    'JOD': 'د.ا',
    'JPY': '¥',
    'KES': 'KSh',
    'KGS': 'лв',
    'KHR': '៛',
    'KMF': 'CF',
    'KPW': '₩',
    'KRW': '₩',
    'KWD': 'د.ك',
    'KYD': '\$',
    'KZT': '₸',
    'LAK': '₭',
    'LBP': 'ل.ل',
    'LKR': '₨',
    'LRD': '\$',
    'LSL': 'L',
    'LYD': 'ل.د',
    'MAD': 'د.م.',
    'MDL': 'L',
    'MGA': 'Ar',
    'MKD': 'ден',
    'MMK': 'K',
    'MNT': '₮',
    'MOP': 'P',
    'MRU': 'UM',
    'MUR': '₨',
    'MVR': 'ރ.',
    'MWK': 'MK',
    'MXN': '\$',
    'MYR': 'RM',
    'MZN': 'MT',
    'NAD': '\$',
    'NGN': '₦',
    'NIO': 'C\$',
    'NOK': 'kr',
    'NPR': '₨',
    'NZD': '\$',
    'OMR': 'ر.ع.',
    'PAB': 'B/.',
    'PEN': 'S/',
    'PGK': 'K',
    'PHP': '₱',
    'PKR': '₨',
    'PLN': 'zł',
    'PYG': '₲',
    'QAR': 'ر.ق',
    'RON': 'L',
    'RSD': 'дин',
    'RUB': '₽',
    'RWF': 'FRw',
    'SAR': 'ر.س',
    'SBD': '\$',
    'SCR': '₨',
    'SDG': 'ج.س.',
    'SEK': 'kr',
    'SGD': '\$',
    'SHP': '£',
    'SLL': 'Le',
    'SOS': 'S',
    'SRD': '\$',
    'SSP': '£',
    'STN': 'Db',
    'SVC': '\$',
    'SYP': '£',
    'SZL': 'L',
    'THB': '฿',
    'TJS': 'SM',
    'TMT': 'T',
    'TND': 'د.ت',
    'TOP': 'T\$',
    'TRY': '₺',
    'TTD': '\$',
    'TWD': 'NT\$',
    'TZS': 'TSh',
    'UAH': '₴',
    'UGX': 'USh',
    'USD': '\$',
    'UYU': '\$U',
    'UZS': 'лв',
    'VND': '₫',
    'VUV': 'Vt',
    'WST': 'WS\$',
    'XAF': 'FCFA',
    'XCD': '\$',
    'XOF': 'CFA',
    'XPF': '₣',
    'YER': '﷼',
    'ZAR': 'R',
    'ZMW': 'ZK',
    'ZWL': 'Z\$',
  };

  static double renderPrice(
    double amount,
    String currencySymbol,
    String coinLetterCode,
    Map prices,
  ) {
    if (prices.isEmpty || !prices.containsKey(coinLetterCode)) {
      return 0.0;
    }
    if (currencySymbol != 'USD') {
      return prices[currencySymbol] * amount * prices[coinLetterCode];
    }
    return amount * prices[coinLetterCode];
  }

  static void checkUpdate(AppSettingsProvider settings) async {
    LoggerWrapper.logInfo(
      'PriceTicker',
      'checkUpdate',
      'checking price update',
    );

    final RateUpdateTime = DateTime.now().subtract(const Duration(minutes: 10));

    if (settings.latestTickerUpdate.isBefore(RateUpdateTime)) {
      LoggerWrapper.logInfo(
        'PriceTicker',
        'checkUpdate',
        'last update older than 10 minutes (${settings.latestTickerUpdate})',
      );

      final data = await getDataFromTicker();

      if (!data.containsKey(settings.selectedCurrency)) {
        settings.setSelectedCurrency('USD');
      }

      if (!mapEquals(data, settings.exchangeRates)) {
        final valuesValid = data.values.every(
          (element) => element is double || element is int,
        );
        if (valuesValid) {
          LoggerWrapper.logInfo(
            'PriceTicker',
            'checkUpdate',
            'price data updated $data',
          );
          settings.setExchangeRates(data);
        } else {
          LoggerWrapper.logError(
            'PriceTicker',
            'checkUpdate',
            'parser data not valid',
          );
        }
      }

      settings.setLatestTickerUpdate(DateTime.now());
    } else {
      LoggerWrapper.logInfo(
        'PriceTicker',
        'checkUpdate',
        'last update happened within 10 minutes. ${settings.latestTickerUpdate}',
      );
    }
  }

  static void startPeriodicUpdates(AppSettingsProvider settings) {
    if (_isUpdating) return;
    _isUpdating = true;

    Timer.periodic(const Duration(minutes: 10), (Timer timer) {
      checkUpdate(settings);
    });
  }
}
