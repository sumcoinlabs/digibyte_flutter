import 'package:digibyte/tools/app_localizations.dart';
import 'package:digibyte/tools/app_themes.dart';
import 'package:digibyte/widgets/buttons.dart';
import 'package:digibyte/widgets/double_tab_to_clipboard.dart';
import 'package:digibyte/widgets/wallet/wallet_home/wallet_home_qr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('WIF readable in light and dark at both widths', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      tester.platformDispatcher.clearTextScaleFactorTestValue,
    );

    final translations = AppLocalizations(const Locale('en'));
    await translations.load();
    AppLocalizations.instance = translations;

    final mode = ValueNotifier<ThemeMode>(ThemeMode.light);
    addTearDown(mode.dispose);

    // Synthetic test data, never an actual private key.
    final sample = 'L${List.filled(51, '2').join()}';

    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: mode,
        builder: (context, themeMode, _) => MaterialApp(
          theme: MyTheme.getTheme(ThemeMode.light),
          darkTheme: MyTheme.getTheme(ThemeMode.dark),
          themeMode: themeMode,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => WalletHomeQr.showWifQrDialog(context, sample),
                child: const Text('Open WIF'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Open WIF'), findsOneWidget);
    await tester.tap(find.text('Open WIF'));
    await tester.pumpAndSettle();

    // Keep this same dialog open throughout all four checks.
    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      mode.value = themeMode;

      for (final width in [320.0, 375.0, 428.0]) {
        tester.view.physicalSize = Size(width, width == 320.0 ? 568 : 900);

        for (final scale in [1.0, 1.3, 1.6, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull,
              reason: 'Layout error at width $width, scale $scale');

          final keyRect = tester.getRect(
            find.byType(SelectableText),
          );
          final shareRect = tester.getRect(
            find.byType(PeerButtonBorder),
          );

          expect(keyRect.bottom, lessThan(shareRect.top),
              reason: 'WIF overlaps Share');

          // SimpleDialog scrolls on small screens with large text.
          await tester.ensureVisible(
            find.byType(PeerButtonBorder),
          );
          await tester.pumpAndSettle();

          final visibleShare = tester.getRect(
            find.byType(PeerButtonBorder),
          );

          expect(
            visibleShare.top,
            greaterThanOrEqualTo(0),
          );

          expect(
            visibleShare.bottom,
            lessThanOrEqualTo(tester.view.physicalSize.height),
          );
        }

        tester.platformDispatcher.textScaleFactorTestValue = 1.0;
        await tester.pumpAndSettle();

        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.byType(PeerButtonBorder), findsOneWidget);

        final key = tester.widget<SelectableText>(
          find.byType(SelectableText),
        );

        expect(key.data, sample);
        expect(key.style?.fontSize, 13);
        expect(key.textAlign, TextAlign.center);

        final keyContext = tester.element(find.byType(SelectableText));
        expect(
          key.style?.color,
          Theme.of(keyContext).colorScheme.onSurface,
        );

        expect(
          find.ancestor(
            of: find.byType(SelectableText),
            matching: find.byType(FittedBox),
          ),
          findsNothing,
        );

        final clipboard = tester.widget<DoubleTabToClipboard>(
          find.byType(DoubleTabToClipboard),
        );

        expect(clipboard.clipBoardData, sample);
        expect(clipboard.withHintText, isTrue);

        final hint = tester.widget<Text>(
          find.text(translations.translate('double_tap_to_copy')),
        );

        expect(hint.style?.fontSize, 12);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
