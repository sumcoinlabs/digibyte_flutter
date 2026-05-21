import 'package:flutter/material.dart';

class SpinningDigiByteIcon extends StatefulWidget {
  const SpinningDigiByteIcon({
    super.key,
  });

  @override
  State<SpinningDigiByteIcon> createState() => _SpinningDigiByteIconState();
}

class _SpinningDigiByteIconState extends State<SpinningDigiByteIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    //init animation controller
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animationController.repeat();
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: Tween(begin: 0.0, end: 1.0).animate(_animationController),
      child: Image.asset(
        'assets/icon/dgb-icon-white-256.png',
        height: 80,
      ),
    );
  }
}
