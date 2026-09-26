import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/services/api_client.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Release builds must never show Flutter's default error widget: an opaque
  // light-gray 400×400 slab that once replaced the chat typing indicator and
  // looked like the whole chat was broken. Any widget that throws in release
  // renders as a compact dark pill instead; debug keeps the loud red screen.
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => Container(
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Opacity(
                    opacity: 0.35 + 0.25 * i,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
  }
  await EasyLocalization.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env missing is ok — fallback to local emulator URL via backend_config.dart
  }
  await Hive.initFlutter();
  await Hive.openBox('settings');
  final savedLang =
      Hive.box('settings').get('language', defaultValue: 'en') as String;
  ApiClient.instance.setLanguage(savedLang);
  await Hive.openBox('farm_profile');
  await Hive.openBox('saved_locations');
  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('gu'),
        Locale('mr'),
        Locale('ta'),
        Locale('te'),
        Locale('kn'),
        Locale('ml'),
        Locale('bn'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: Locale(savedLang),
      child: const ProviderScope(child: WeatherGptApp()),
    ),
  );
}

class WeatherGptApp extends StatelessWidget {
  const WeatherGptApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'WeatherGPT',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: appRouter,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
      );
}
