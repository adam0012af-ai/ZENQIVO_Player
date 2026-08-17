import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/zenqivo_config.dart';
import 'core/localization/app_locale_controller.dart';
import 'core/theme/zenqivo_theme.dart';
import 'features/splash/splash_screen.dart';

class ZenqivoApp extends StatelessWidget {
  const ZenqivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeController = AppLocaleController.instance;
    return AnimatedBuilder(
      animation: localeController,
      builder: (context, _) {
        return MaterialApp(
          title: ZenqivoConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: ZenqivoTheme.dark,
          locale: localeController.locale,
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SplashScreen(),
        );
      },
    );
  }
}
