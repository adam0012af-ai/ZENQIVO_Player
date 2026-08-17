import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/zenqivo_theme.dart';
import '../device/device_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DeviceSetupScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ZenqivoMark(size: 92),
            SizedBox(height: 24),
            Text(
              'ZENQIVO',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
                color: ZenqivoColors.text,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'PLAYER',
              style: TextStyle(
                fontSize: 13,
                letterSpacing: 7,
                color: ZenqivoColors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZenqivoMark extends StatelessWidget {
  const _ZenqivoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .24),
        border: Border.all(color: ZenqivoColors.gold, width: 2),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF26200E), Color(0xFF090909)],
        ),
      ),
      child: const Center(
        child: Text(
          'Z▶',
          style: TextStyle(
            color: ZenqivoColors.goldSoft,
            fontSize: 32,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
