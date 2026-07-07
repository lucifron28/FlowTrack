import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/database/app_database.dart';
import '../../core/services/barcode_service.dart';
import '../../core/services/barcode_print_service.dart';
import '../../core/services/local_auth_service.dart';
import '../../core/services/sample_data_service.dart';
import '../../features/auth/screens/auth_gate.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(database.close);
  return database;
});

final barcodeServiceProvider = Provider<BarcodeService>((ref) {
  return BarcodeService();
});

final barcodePrintServiceProvider = Provider<BarcodePrintService>((ref) {
  return const BarcodePrintService();
});

final localAuthServiceProvider = Provider<LocalAuthService>((ref) {
  return LocalAuthService();
});

final sampleDataServiceProvider = Provider<SampleDataService>((ref) {
  return SampleDataService(ref.watch(appDatabaseProvider));
});

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadSavedTheme();
    return ThemeMode.system;
  }

  Future<void> _loadSavedTheme() async {
    final val = await ref.read(appDatabaseProvider).getSetting('theme_mode');
    if (val != null) {
      state = ThemeMode.values.firstWhere(
        (e) => e.name == val,
        orElse: () => ThemeMode.system,
      );
    }
  }

  void setThemeMode(ThemeMode value) {
    state = value;
    ref.read(appDatabaseProvider).setSetting('theme_mode', value.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.root,
    routes: [
      GoRoute(
        path: AppRoutes.root,
        builder: (context, state) => const AuthGate(),
      ),
    ],
  );
});

class AuthState {
  const AuthState({
    required this.hasOwner,
    required this.isAuthenticated,
    this.ownerName,
  });

  final bool hasOwner;
  final bool isAuthenticated;
  final String? ownerName;

  AuthState copyWith({
    bool? hasOwner,
    bool? isAuthenticated,
    String? ownerName,
  }) {
    return AuthState(
      hasOwner: hasOwner ?? this.hasOwner,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      ownerName: ownerName ?? this.ownerName,
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthController extends AsyncNotifier<AuthState> {
  LocalAuthService get _authService => ref.read(localAuthServiceProvider);

  @override
  Future<AuthState> build() async {
    final hasOwner = await _authService.hasOwnerAccount();
    final ownerName = await _authService.ownerName();
    return AuthState(
      hasOwner: hasOwner,
      isAuthenticated: !hasOwner,
      ownerName: ownerName,
    );
  }

  Future<void> setupOwner({
    required String ownerName,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.setupOwner(ownerName: ownerName, password: password);
      return AuthState(
        hasOwner: true,
        isAuthenticated: true,
        ownerName: ownerName.trim(),
      );
    });
  }

  Future<void> login(String password) async {
    final current =
        state.asData?.value ??
        AuthState(
          hasOwner: await _authService.hasOwnerAccount(),
          isAuthenticated: false,
          ownerName: await _authService.ownerName(),
        );
    final success = await _authService.verifyPassword(password);
    if (!success) {
      state = AsyncValue.data(current);
      throw const AuthException('Invalid password. Please try again.');
    }
    state = AsyncValue.data(
      AuthState(
        hasOwner: true,
        isAuthenticated: true,
        ownerName: await _authService.ownerName(),
      ),
    );
  }

  void logout() {
    final current = state.asData?.value;
    state = AsyncValue.data(
      AuthState(
        hasOwner: true,
        isAuthenticated: false,
        ownerName: current?.ownerName,
      ),
    );
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final todayProvider = Provider<DateTime>((ref) => DateTime.now());
