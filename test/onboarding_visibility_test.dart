import 'package:digibyte/tools/app_themes.dart';
import 'package:digibyte/widgets/buttons.dart';
import 'package:digibyte/widgets/setup/setup_contrast_switch_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('setup controls contrast and switch state in $mode',
        (tester) async {
      bool? changed;
      await tester.pumpWidget(MaterialApp(
        theme: MyTheme.getTheme(ThemeMode.light),
        darkTheme: MyTheme.getTheme(ThemeMode.dark),
        themeMode: mode,
        home: Scaffold(
          body: Column(children: [
            SetupContrastSwitchTile(
              title: 'Allow price feed API',
              value: true,
              onChanged: (value) => changed = value,
            ),
            PeerButtonSetup(action: () {}, text: 'Continue'),
            PeerButton(
              onPrimaryBackground: true,
              action: () {},
              text: 'View License',
            ),
          ]),
        ),
      ));

      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.value, isTrue);
      expect(tile.trackColor!.resolve({WidgetState.selected}), Colors.white);
      expect(tile.trackColor!.resolve({}), const Color(0xFF1A2D42));
      expect(tile.thumbColor!.resolve({WidgetState.selected}),
          const Color(0xFF102E44));
      expect(tile.thumbColor!.resolve({}), Colors.white);

      final buttons = tester
          .widgetList<ElevatedButton>(
            find.byType(ElevatedButton),
          )
          .toList();
      expect(buttons.length, 2);
      expect(buttons[0].style!.backgroundColor!.resolve({}), Colors.white);
      expect(buttons[1].style!.backgroundColor!.resolve({}), Colors.white);
      await tester.tap(find.byType(Switch));
      expect(changed, isFalse);
    });
  }
}
