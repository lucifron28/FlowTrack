import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppMode {
  production,
  demo;

  bool get isDemo => this == AppMode.demo;
  bool get isProduction => this == AppMode.production;
}

class AppEnvironment {
  const AppEnvironment._();

  static const String _modeEnvKey = 'FLOWTRACK_MODE';

  static AppMode get mode {
    const value = String.fromEnvironment(
      _modeEnvKey,
      defaultValue: 'production',
    );
    return parse(value);
  }

  static AppMode parse(String value) {
    switch (value.toLowerCase().trim()) {
      case 'demo':
        return AppMode.demo;
      case 'production':
      default:
        return AppMode.production;
    }
  }
}

final appModeProvider = Provider<AppMode>((ref) {
  return AppEnvironment.mode;
});
