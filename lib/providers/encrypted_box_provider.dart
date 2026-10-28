import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/hive/coin_wallet.dart';
import '../models/hive/server.dart';
import '../tools/logger_wrapper.dart';

class EncryptedBoxProvider with ChangeNotifier {
  final Map<String, Box> _cryptoBox = {};
  Uint8List? _encryptionKey;
  Future<Uint8List>? _loadingKey;
  String? _passCode;
  int _failedAuths = 0;
  int _failedAuthAttempts = 0;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Keep this setting scoped to the AES box key; authentication secrets retain
  // their existing protection and migration/backup semantics.
  static const IOSOptions _backgroundKeyOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );
  static const String _migrationFlag = 'dgb_key_first_unlock_v1';

  /// Reads the EXISTING wallet encryption key. Background callers never
  /// generate a key and never trigger a Keychain migration while locked.
  static Future<Uint8List?> readStoredEncryptionKey({
    bool background = false,
  }) async {
    const storage = FlutterSecureStorage();
    try {
      String? encoded;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final prefs = await SharedPreferences.getInstance();
        final migrated = prefs.getBool(_migrationFlag) == true;
        if (background) {
          if (!migrated) {
            LoggerWrapper.logWarn('WalletKey', 'background',
                'Keychain migration pending; skipping background sync');
            return null;
          }
          encoded = await storage.read(
            key: 'key',
            iOptions: _backgroundKeyOptions,
          );
        } else {
          // Version 9.2.4 supports updating existing Keychain accessibility.
          // Fallback keeps wallets created with the old default readable.
          encoded = await storage.read(
            key: 'key',
            iOptions: _backgroundKeyOptions,
          );
          encoded ??= await storage.read(key: 'key');
          if (encoded != null && !migrated) {
            await storage.write(
              key: 'key',
              value: encoded,
              iOptions: _backgroundKeyOptions,
            );
            final verified = await storage.read(
              key: 'key',
              iOptions: _backgroundKeyOptions,
            );
            if (verified != encoded) {
              throw StateError('Encryption key migration verification failed');
            }
            if (!await prefs.setBool(_migrationFlag, true)) {
              LoggerWrapper.logWarn('WalletKey', 'migration',
                  'Migration verified but background marker not saved');
            }
            LoggerWrapper.logInfo('WalletKey', 'migration',
                'Existing key migrated and verified; key bytes unchanged');
          }
        }
      } else {
        encoded = await storage.read(key: 'key');
      }
      if (encoded == null) {
        LoggerWrapper.logWarn('WalletKey', background ? 'background' : 'read',
            'Encryption key unavailable');
        return null;
      }
      final result = base64Url.decode(encoded);
      if (result.length != 32) {
        throw StateError('Stored encryption key has unexpected length');
      }
      LoggerWrapper.logInfo('WalletKey', background ? 'background' : 'read',
          'Existing encryption key read successfully');
      return result;
    } on PlatformException catch (e) {
      LoggerWrapper.logError('WalletKey', background ? 'background' : 'read',
          'Keychain operation failed: code=${e.code}; status=${e.details}');
      rethrow;
    } catch (e) {
      LoggerWrapper.logError('WalletKey', background ? 'background' : 'read',
          'Key operation failed: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<Uint8List?> get key async {
    if (_encryptionKey != null) return _encryptionKey;
    _loadingKey ??= _loadOrCreateKey();
    try {
      _encryptionKey = await _loadingKey;
      return _encryptionKey;
    } catch (_) {
      _loadingKey = null; // a temporary OS denial must not poison future reads
      rethrow;
    }
  }

  Future<Uint8List> _loadOrCreateKey() async {
    final existing = await readStoredEncryptionKey();
    if (existing != null) return existing;

    // A failed read must NEVER cause an established wallet to be re-keyed.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('setupFinished') == true ||
        prefs.getBool('importedSeed') == true ||
        await Hive.boxExists('vaultBox') ||
        await Hive.boxExists('optionsBox') ||
        await Hive.boxExists('wallets')) {
      LoggerWrapper.logError('WalletKey', 'create',
          'Existing wallet detected but key unavailable; refusing to generate replacement');
      throw StateError('Existing wallet encryption key unavailable');
    }

    final created = Hive.generateSecureKey();
    await _secureStorage.write(
      key: 'key',
      value: base64UrlEncode(created),
      iOptions: (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
          ? _backgroundKeyOptions
          : const IOSOptions(),
    );
    final verified = await readStoredEncryptionKey();
    if (verified == null || !listEquals(created, verified)) {
      LoggerWrapper.logError('WalletKey', 'create',
          'New key could not be verified; refusing to initialize wallet');
      throw StateError('New encryption key verification failed');
    }
    LoggerWrapper.logInfo(
        'WalletKey', 'create', 'Fresh-install key created and verified');
    return verified;
  }

  Future<String?> get passCode async {
    _passCode ??= await _secureStorage.read(key: 'passCode');
    return _passCode;
  }

  Future<bool> setPassCode(String passCode) async {
    await _secureStorage.write(key: 'passCode', value: passCode);
    _passCode = passCode;
    return true;
  }

  Future<int> get failedAuths async {
    if (_failedAuths == 0) {
      final result = await _secureStorage.read(key: 'failedAuths');
      if (result == null) {
        _failedAuths = 0;
      } else {
        _failedAuths = int.parse(result);
      }
    }
    return _failedAuths;
  }

  Future<void> setFailedAuths(int newInt) async {
    await _secureStorage.write(key: 'failedAuths', value: newInt.toString());
    _failedAuths = newInt;
  }

  Future<int> get failedAuthAttempts async {
    if (_failedAuthAttempts == 0) {
      final result = await _secureStorage.read(key: 'failedAuthAttempts');
      if (result == null) {
        _failedAuthAttempts = 0;
      } else {
        _failedAuthAttempts = int.parse(result);
      }
    }
    return _failedAuthAttempts;
  }

  Future<void> setFailedAuthAttempts(int newInt) async {
    await _secureStorage.write(
      key: 'failedAuthAttempts',
      value: newInt.toString(),
    );
    _failedAuthAttempts = newInt;
  }

  Future<Box?> getGenericBox(String name) async {
    if (!_cryptoBox.containsKey(name)) {
      _cryptoBox[name] = await Hive.openBox(
        name,
        encryptionCipher: HiveAesCipher(await key as Uint8List),
      );
    }
    return _cryptoBox[name];
  }

  Future<Box<Server>> getServerBox(String identifier) async {
    return await Hive.openBox<Server>(
      'serverBox-$identifier',
      encryptionCipher: HiveAesCipher(await key as Uint8List),
    );
  }

  Future<Box<CoinWallet>> getWalletBox() async {
    return await Hive.openBox<CoinWallet>(
      'wallets',
      encryptionCipher: HiveAesCipher(await key as Uint8List),
    );
  }
}
