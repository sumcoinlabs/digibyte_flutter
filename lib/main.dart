import 'dart:async';
import 'dart:io';

//import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:digicoinlib_flutter/digicoinlib_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theme_mode_handler/theme_mode_handler.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:location/location.dart';
import 'package:flutter_app_badge_control/flutter_app_badge_control.dart';


import 'firebase_options.dart';
import 'android_background_fetch.dart';

import 'models/hive/app_options.dart';
import 'models/hive/pending_notifications.dart';
import 'models/hive/server.dart';
import 'models/hive/coin_wallet.dart';
import 'models/hive/wallet_address.dart';
import 'models/hive/wallet_transaction.dart';
import 'models/hive/wallet_utxo.dart';

import 'providers/app_settings_provider.dart';
import 'providers/server_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/encrypted_box_provider.dart';

import 'screens/auth_jail.dart';
import 'screens/secure_storage_error_screen.dart';
import 'screens/setup/setup_landing.dart';
import 'screens/wallet/wallet_list.dart';

import 'tools/logger_wrapper.dart';
import 'tools/theme_manager.dart';
import 'tools/in_app_review.dart';
import 'tools/app_localizations.dart';
import 'tools/app_routes.dart';
import 'tools/app_themes.dart';
import 'tools/session_checker.dart';

import 'widgets/spinning_digibyte_icon.dart';
import 'widgets/collector.dart';

// Global variables
late bool setupFinished;
late Widget _homeWidget;
late Locale _locale;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Use a named app to avoid the "[DEFAULT]" app duplicate error
  if (Firebase.apps.where((app) => app.name == 'background').isEmpty) {
    await Firebase.initializeApp(
      name: 'background',
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialize the default Firebase app if it doesn't exist already
  if (Firebase.apps.isEmpty) {
    // If your app is already configured by iOS using GoogleService-Info.plist,
    // just call initializeApp without options or skip if you want to rely on auto-initialization.
    await Firebase.initializeApp();
  }

  // Register the background handler AFTER ensuring Firebase is initialized
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final prefs = await SharedPreferences.getInstance();
  setupFinished = prefs.getBool('setupFinished') ?? false;

  _locale = Locale(prefs.getString('language_code') ?? 'und');

  // Initialize Android Background Fetch
  await initAndroidBackgroundFetch(); // see lib/android_background_fetch.dart

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: analytics);

  MobileAds.instance.initialize();

  if (!setupFinished) {
    await prefs.clear();
    LoggerWrapper.logInfo('main', 'SharedPreferences', 'SharedPreferences flushed');
  }

  await Hive.initFlutter();
  Hive.registerAdapter(CoinWalletAdapter());
  Hive.registerAdapter(WalletTransactionAdapter());
  Hive.registerAdapter(WalletAddressAdapter());
  Hive.registerAdapter(WalletUtxoAdapter());
  Hive.registerAdapter(AppOptionsStoreAdapter());
  Hive.registerAdapter(ServerAdapter());
  Hive.registerAdapter(PendingNotificationAdapter());

  await loadDigiCoinlib();

  final encryptedBoxProvider = EncryptedBoxProvider();
  final walletProvider = WalletProvider(encryptedBoxProvider);
  Collector.init(walletProvider);

  var flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  FlutterAppBadgeControl.updateBadgeCount(1); // set
  FlutterAppBadgeControl.removeBadge();      // clear


  final firebaseMessaging = FirebaseMessaging.instance;

  // Register notification taps early during startup.
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('FCM notification opened from background: ${message.messageId}');
    flutterLocalNotificationsPlugin.cancelAll();
  });

  // Handle notification taps that launch a terminated app.
  final initialMessage = await firebaseMessaging.getInitialMessage();
  if (initialMessage != null) {
    print('FCM notification opened from terminated state: ${initialMessage.messageId}');
  }

  // Create a silent notification channel
  const AndroidNotificationChannel silentChannel = AndroidNotificationChannel(
    'silent_channel', // ID of the channel
    'Silent Notifications', // Name of the channel
    description: 'This channel does not make a sound.',
    importance: Importance.low, // Ensures no sound or vibration
    sound: RawResourceAndroidNotificationSound(''), // Empty sound
  );

  // Register the silent notification channel
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(silentChannel);

  int appOpens = prefs.getInt('appOpens') ?? 0;
  print('App opens retrieved from SharedPreferences: $appOpens');
  appOpens++;
  await prefs.setInt('appOpens', appOpens);
  print('App opens incremented to: $appOpens');

  // Check if permissions have already been granted or denied
  bool notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
  bool locationPermissionGranted = prefs.getBool('locationPermissionGranted') ?? false;

  // Additional variables for managing prompt logic
  int permissionPromptCount = prefs.getInt('permissionPromptCount') ?? 0;
  String? lastPromptTimestamp = prefs.getString('lastPromptTimestamp');
  DateTime now = DateTime.now();
  DateTime? lastPromptTime = lastPromptTimestamp != null ? DateTime.parse(lastPromptTimestamp) : null;

  // Define a grace period between prompts (e.g., 7 days)
  Duration gracePeriod = Duration(days: 7);
  bool canPromptAgain = lastPromptTime == null || now.difference(lastPromptTime) > gracePeriod;

  // Introduce a queued flag for immediate next login prompt
  bool queuedForPrompt = prefs.getBool('queuedForPrompt') ?? false;

  // Check if prompts should be triggered now
  bool shouldPromptNotifications = (!notificationsEnabled && (queuedForPrompt || (appOpens >= 3 && canPromptAgain))) ||
      (!notificationsEnabled && permissionPromptCount < 3);

  bool shouldPromptLocation = (!locationPermissionGranted && (queuedForPrompt || (appOpens >= 4 && canPromptAgain))) ||
      (!locationPermissionGranted && permissionPromptCount < 3);

  if (queuedForPrompt) {
    print('User is queued for a prompt.');
  }

  // Prompt for notifications
  if (shouldPromptNotifications) {
    print('Requesting notification permissions...');
    NotificationSettings settings = await firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    bool granted = settings.authorizationStatus == AuthorizationStatus.authorized;
    prefs.setBool('notificationsEnabled', granted);

    // Update prompt count and last prompt timestamp
    prefs.setInt('permissionPromptCount', permissionPromptCount + 1);
    prefs.setString('lastPromptTimestamp', now.toIso8601String());

    print('Notification permissions result: ${settings.authorizationStatus}');
    if (!granted) {
      print('User denied notification permissions.');
    }
  }

  // Prompt for location
  if (shouldPromptLocation) {
    print('Requesting location permissions...');
    final location = Location();

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled. Requesting to enable...');
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        print('User declined to enable location services.');
        prefs.setBool('queuedForPrompt', false); // Reset queued flag
        return; // Exit gracefully
      }
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied || permissionGranted == PermissionStatus.deniedForever) {
      print('Location permission is currently denied or denied forever. Requesting...');
      permissionGranted = await location.requestPermission();
      bool granted = permissionGranted == PermissionStatus.granted;
      prefs.setBool('locationPermissionGranted', granted);

      // Update prompt count and last prompt timestamp
      prefs.setInt('permissionPromptCount', permissionPromptCount + 1);
      prefs.setString('lastPromptTimestamp', now.toIso8601String());

      print('Location permission result: $permissionGranted');
      if (!granted) {
        print('User denied location permissions.');
      }
    } else {
      prefs.setBool('locationPermissionGranted', true);
      print('Location permissions already granted.');
    }
  }

  // Reset the queued prompt flag after prompting
  if (queuedForPrompt) {
    prefs.setBool('queuedForPrompt', false);
    print('Queued prompt has been reset.');
  }

  // Queue the user for the next login prompt, only if permissions are not yet granted
  if (!notificationsEnabled || !locationPermissionGranted) {
    prefs.setBool('queuedForPrompt', true);
    print('User queued for next login prompt.');
  }




  FirebaseMessaging.instance.getToken().then((String? token) {
    if (token != null && token.isNotEmpty) {
      Collector.getAppVersion().then((String version) {
        Collector.getLocation().then((Map<String, String?> locationData) async {
          if (locationData.isNotEmpty) {
            double balance = await Collector.getBalance();
            String date = Collector.getDate();
            String os = Collector.getOperatingSystem();
            double totalSent = 0;
            int transactions = 0;
            await Collector.storeUserData(
              token, balance, locationData, date, os, totalSent, transactions, version,
            );
          } else {
            print('Location is null, not adding to Firestore.');
          }
        });
      });
    } else {
      print('FCM token is null or empty, not adding to Firestore.');
    }
  });

  FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
    print('Token refreshed: $token');
  });

  String? apnsToken = await firebaseMessaging.getAPNSToken();
  print('APNS Token: $apnsToken');

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);

  const initializationSettingsAndroid = AndroidInitializationSettings('@drawable/splash');
  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: DarwinInitializationSettings(),
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
      if (notificationResponse.payload != null) {
        LoggerWrapper.logInfo('notification', 'payload', notificationResponse.payload!);
      }
    },
  );

  final notificationAppLaunchDetails = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  var secureStorageError = false;
  var failedAuths = 0;
  var sessionExpired = await checkSessionExpired();

  try {
    const secureStorage = FlutterSecureStorage();
    if (!setupFinished) {
      await secureStorage.deleteAll();
      LoggerWrapper.logInfo('main', 'secureStorage', 'secureStorage flushed');
    }
    failedAuths = int.parse(await secureStorage.read(key: 'failedAuths') ?? '0');
  } catch (e) {
    secureStorageError = true;
    LoggerWrapper.logError('Main', 'secureStorage', e.toString());
  }

  if (secureStorageError == true) {
    _homeWidget = const SecureStorageFailedScreen();
  } else {
    if (setupFinished == false || sessionExpired == true) {
      _homeWidget = const SetupLandingScreen();
    } else if (failedAuths > 0) {
      _homeWidget = const AuthJailScreen(jailedFromHome: true);
    } else {
      _homeWidget = WalletListScreen(
        fromColdStart: true,
        walletToOpenDirectly: notificationAppLaunchDetails?.notificationResponse?.payload ?? '',
      );
    }
  }

  if (!kIsWeb) {
    await FlutterLogs.initLogs(
      logLevelsEnabled: [LogLevel.INFO, LogLevel.WARNING, LogLevel.ERROR, LogLevel.SEVERE],
      timeStampFormat: TimeStampFormat.TIME_FORMAT_READABLE,
      directoryStructure: DirectoryStructure.FOR_DATE,
      logFileExtension: LogFileExtension.LOG,
      logsWriteDirectoryName: 'MyLogs',
      logsExportDirectoryName: 'MyLogs/Exported',
      debugFileOperations: true,
      isDebuggable: true,
    );

    LoggerWrapper.logInfo('main', 'initLogs', 'Init logs..');

    var packageInfo = await PackageInfo.fromPlatform();
    LoggerWrapper.logInfo('main', 'initLogs', 'Version ${packageInfo.version} Build ${packageInfo.buildNumber}');
  }

  final inAppReviewService = InAppReviewService();
  await inAppReviewService.incrementAppOpens();

  runApp(const SumcoinApp());
}

class SumcoinApp extends StatelessWidget {
  const SumcoinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: EncryptedBoxProvider()),
        ChangeNotifierProvider(create: (context) {
          WalletProvider walletProvider = WalletProvider(
            Provider.of<EncryptedBoxProvider>(context, listen: false),
          );
          Collector.init(walletProvider);
          return walletProvider;
        }),
        ChangeNotifierProvider(create: (context) {
          return AppSettingsProvider(
            Provider.of<EncryptedBoxProvider>(context, listen: false),
          );
        }),
        ChangeNotifierProvider(create: (context) {
          return ServerProvider(
            Provider.of<EncryptedBoxProvider>(context, listen: false),
          );
        }),
        ChangeNotifierProvider.value(value: ConnectionProvider()),
      ],
      child: ThemeModeHandler(
        manager: ThemeManager(),
        builder: (ThemeMode themeMode) {
          return GlobalLoaderOverlay(
            useDefaultLoading: false,
            overlayColor: Colors.grey.withOpacity(0.6),
            overlayWidgetBuilder: (_) => const Center(child: SpinningDigiByteIcon()),
            child: MaterialApp(
              title: 'Sumcoin',
              debugShowCheckedModeBanner: false,
              supportedLocales: AppLocalizations.availableLocales.values.map((e) {
                var (locale, _) = e;
                return locale;
              }),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              locale: _locale == const Locale('und') ? null : _locale,
              themeMode: themeMode,
              theme: MyTheme.getTheme(ThemeMode.light),
              darkTheme: MyTheme.getTheme(ThemeMode.dark),
              home: _homeWidget,
              routes: Routes.getRoutes(),
            ),
          );
        },
      ),
    );
  }
}
