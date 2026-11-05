import 'package:digibyte/tools/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DigiByte light theme configuration', () {
    final theme = MyTheme.getTheme(ThemeMode.light);

    expect(theme.brightness, Brightness.light);
    expect(theme.useMaterial3, isFalse);
    expect(
      theme.scaffoldBackgroundColor,
      LightColors.background,
    );
    expect(
      theme.bottomAppBarTheme.color,
      LightColors.background,
    );
  });

  test('DigiByte dark theme configuration', () {
    final theme = MyTheme.getTheme(ThemeMode.dark);

    expect(theme.brightness, Brightness.dark);
    expect(theme.useMaterial3, isFalse);
    expect(
      theme.scaffoldBackgroundColor,
      DarkColors.background,
    );
    expect(
      theme.bottomAppBarTheme.color,
      DarkColors.background,
    );
  });

  testWidgets('DigiByte theme applies to widgets', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: MyTheme.getTheme(ThemeMode.light),
        darkTheme: MyTheme.getTheme(ThemeMode.dark),
        themeMode: ThemeMode.dark,
        home: const Scaffold(
          body: Text('DigiByte Wallet'),
        ),
      ),
    );

    final text = find.text('DigiByte Wallet');
    expect(text, findsOneWidget);

    final context = tester.element(text);
    expect(
      Theme.of(context).brightness,
      Brightness.dark,
    );
  });
}
