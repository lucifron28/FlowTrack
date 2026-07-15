import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_auth_service.dart';
import '../../../shared/providers/app_providers.dart';
import '../domain/auth_state.dart';

class AuthController extends AsyncNotifier<AuthState> {
  LocalAuthService get _authService => ref.read(localAuthServiceProvider);

  @override
  Future<AuthState> build() async {
    try {
      final hasOwner = await _authService.hasOwnerAccount();
      final ownerName = await _authService.ownerName();
      return AuthState(
        status: AuthStatus.unauthenticated,
        hasOwner: hasOwner,
        ownerName: ownerName,
      );
    } catch (e) {
      return const AuthState(
        status: AuthStatus.unauthenticated,
        hasOwner: false,
      );
    }
  }

  Future<void> setupOwner({
    required String ownerName,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.setupOwner(ownerName: ownerName, password: password);
      return AuthState(
        status: AuthStatus.authenticated,
        hasOwner: true,
        ownerName: ownerName.trim(),
      );
    });
  }

  Future<void> updateOwnerName(String name) async {
    final current = state.valueOrNull;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.updateOwnerName(name);
      return AuthState(
        status: current?.status ?? AuthStatus.authenticated,
        hasOwner: true,
        ownerName: name.trim(),
      );
    });
  }

  Future<void> login(String password) async {
    final current = state.valueOrNull ??
        AuthState(
          status: AuthStatus.unauthenticated,
          hasOwner: await _authService.hasOwnerAccount(),
          ownerName: await _authService.ownerName(),
        );

    state = AsyncValue.data(current.copyWith(status: AuthStatus.authenticating));

    try {
      final success = await _authService.verifyPassword(password);
      if (!success) {
        state = AsyncValue.data(current.copyWith(status: AuthStatus.unauthenticated));
        throw const AuthException('Invalid password. Please try again.');
      }
      state = AsyncValue.data(
        AuthState(
          status: AuthStatus.authenticated,
          hasOwner: true,
          ownerName: await _authService.ownerName(),
        ),
      );
    } catch (e) {
      state = AsyncValue.data(current.copyWith(status: AuthStatus.unauthenticated));
      rethrow;
    }
  }

  void logout() {
    final current = state.valueOrNull;
    state = AsyncValue.data(
      AuthState(
        status: AuthStatus.unauthenticated,
        hasOwner: true,
        ownerName: current?.ownerName,
      ),
    );
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
