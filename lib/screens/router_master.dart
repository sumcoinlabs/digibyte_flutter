import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tools/app_routes.dart';
import '../tools/logger_wrapper.dart';
import 'secure_storage_error_screen.dart';
import 'auth_jail.dart';

enum RouteTypes { requiresSetupFinished, requiresArguments, setupOnly }

class RouterMaster extends StatefulWidget {
  final Widget widget;
  final RouteTypes routeType;

  const RouterMaster({
    super.key,
    required this.widget,
    required this.routeType,
  });

  @override
  State<RouterMaster> createState() => _RouterMasterState();
}

class _RouterMasterState extends State<RouterMaster> {
  bool _initial = true;
  bool _loading = false;
  Widget? widgetToRender;

  @override
  void didChangeDependencies() async {
    if (_initial && !_loading) {
      _loading = true;
      final modalRoute = ModalRoute.of(context)!;
      var prefs = await SharedPreferences.getInstance();
      var setupFinished = prefs.getBool('setupFinished') ?? false;

      if (widget.routeType == RouteTypes.setupOnly && setupFinished) {
        //setup is finished and setupOnly screen has been called
        Future.delayed(
          const Duration(seconds: 0),
          () => Navigator.of(context).pushReplacementNamed(Routes.walletList),
        );
      } else if (!setupFinished &&
          widget.routeType == RouteTypes.requiresSetupFinished) {
        Future.delayed(
          const Duration(seconds: 0),
          () => Navigator.of(context).pushReplacementNamed('/'),
        );
      } else if (!setupFinished && widget.routeType == RouteTypes.setupOnly) {
        widgetToRender = widget.widget;
        //TODO don't allow unordered access to setup widgets if setup is not finished
      } else if (widget.routeType == RouteTypes.requiresArguments &&
          modalRoute.settings.arguments == null) {
        Future.delayed(
          const Duration(seconds: 0),
          () => Navigator.of(context).pushReplacementNamed('/'),
        );
      } else {
        widgetToRender = widget.widget;
      }

      const secureStorage = FlutterSecureStorage();
      int failedAuths;
      var retry = 0;
      while (true) {
        try {
          failedAuths = int.parse(
            await secureStorage.read(key: 'failedAuths') ?? '0',
          );
          LoggerWrapper.logInfo('RouterMaster', 'auth',
              'Authentication lockout state loaded successfully');
          break;
        } on PlatformException catch (e) {
          LoggerWrapper.logError('RouterMaster', 'auth',
              'Keychain lockout read failed: code=${e.code}; status=${e.details}');
          if (!e.toString().contains('-25308')) {
            if (mounted)
              setState(() {
                widgetToRender = const SecureStorageFailedScreen();
                _initial = false;
              });
            return;
          }
          retry++;
          final delay = retry < 3 ? retry : 5;
          LoggerWrapper.logWarn('RouterMaster', 'auth',
              'Keychain unavailable; retrying automatically in ${delay}s');
          await Future<void>.delayed(Duration(seconds: delay));
          if (!mounted) return;
        } catch (e) {
          LoggerWrapper.logError('RouterMaster', 'auth',
              'Lockout state read failed: ${e.runtimeType}');
          if (mounted)
            setState(() {
              widgetToRender = const SecureStorageFailedScreen();
              _initial = false;
            });
          return;
        }
      }

      if (failedAuths > 0) {
        widgetToRender = const AuthJailScreen();
      }

      setState(() {
        _initial = false;
      });
    }
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return widgetToRender ??
        const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
  }
}
