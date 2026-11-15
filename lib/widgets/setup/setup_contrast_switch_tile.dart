import 'package:flutter/material.dart';

/// High-contrast setup switch for screens with a solid blue background.
class SetupContrastSwitchTile extends StatelessWidget {
  const SetupContrastSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.labelKey,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key? labelKey;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        title,
        key: labelKey,
        style: const TextStyle(color: Colors.white, fontSize: 17),
      ),
      value: value,
      onChanged: onChanged,
      // White track + navy thumb when enabled; reversed when disabled.
      // The contrasting thumb position and colors make the state obvious.
      trackColor: WidgetStateProperty.resolveWith<Color?>((states) =>
          states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFF1A2D42)),
      thumbColor: WidgetStateProperty.resolveWith<Color?>((states) =>
          states.contains(WidgetState.selected)
              ? const Color(0xFF102E44)
              : Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll<Color?>(Colors.white),
    );
  }
}
