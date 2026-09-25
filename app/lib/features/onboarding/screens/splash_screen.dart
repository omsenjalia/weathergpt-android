import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atmosphere_background.dart';
import '../../home/theme/atmosphere_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final done = Hive.box('settings')
          .get('onboarding_complete', defaultValue: false) as bool;
      context.go(done ? '/home' : '/onboarding/language');
    });
  }

  /// A calm dusk palette — the same atmosphere system the rest of the app
  /// uses, so the very first frame already feels like WeatherGPT.
  static const AtmospherePalette _dusk = AtmospherePalette(
    top: Color(0xFF1E1B4B),
    mid: Color(0xFF134E4A),
    bottom: Color(0xFF0B1220),
    accent: Color(0xFF2DD4BF),
    glow: Color(0xFF2DD4BF),
    card: Color(0xE60F172A),
    text: Color(0xFFF8FAFC),
    textMuted: Color(0xFF94A3B8),
    orbStart: Color(0xFF2DD4BF),
    orbEnd: Color(0xFF38BDF8),
    showSun: false,
    showMoon: true,
    sunY: 1.3,
    moonY: 0.3,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AtmosphereBackground(palette: _dusk),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientAccent,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.45),
                          blurRadius: 42,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.wb_cloudy_rounded,
                        size: 44, color: Colors.black),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'common.weather_gpt'.tr(),
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'onboarding.splash_tagline'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const SizedBox(
                    width: 132,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                      color: AppColors.accent,
                      backgroundColor: Color(0x33FFFFFF),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'onboarding.splash_footer'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
