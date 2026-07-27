import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/app_providers.dart';

class FlowTrackApp extends ConsumerWidget {
  const FlowTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final fontScale = ref.watch(fontScaleProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final minimumFactor = fontScale.minimumFactor;
        final effectiveScaler = minimumFactor == null
            ? mediaQuery.textScaler
            : mediaQuery.textScaler.clamp(
                minScaleFactor: minimumFactor,
              );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: effectiveScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
