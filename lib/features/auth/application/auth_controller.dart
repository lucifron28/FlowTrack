import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_auth_service.dart';
import '../../../shared/providers/app_providers.dart';


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
    } catch (_) {
      return const AuthState(
        status: AuthStatus.initializationFailed,
        hasOwner: false,
      );
    }
  }

  Future<bool> setupOwner({
    required String ownerName,
    required String password,
  }) async {
    final prev = state.asData?.value;
    if (prev == null) return false;
    if (prev.operation != AuthOperation.idle) return false;

    state = AsyncValue.data(
      prev.copyWith(
        operation: AuthOperation.settingUpOwner,
        errorMessage: null,
      ),
    );

    try {
      await _authService.setupOwner(ownerName: ownerName, password: password);
      final current = state.asData?.value;
      if (current == null) return false;
      state = AsyncValue.data(AuthState(
        status: AuthStatus.authenticated,
        hasOwner: true,
        ownerName: ownerName.trim(),
      ));
      return true;
    } catch (_) {
      final current = state.asData?.value;
      if (current == null) return false;
      state = AsyncValue.data(
        current.copyWith(
          operation: AuthOperation.idle,
          errorMessage: 'Setup failed. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<bool> updateOwnerName(String name) async {
    final prev = state.asData?.value;
    if (prev == null) return false;
    if (prev.operation != AuthOperation.idle) return false;

    state = AsyncValue.data(
      prev.copyWith(
        operation: AuthOperation.updatingProfile,
        errorMessage: null,
      ),
    );

    try {
      await _authService.updateOwnerName(name);
      final current = state.asData?.value;
      if (current == null || current.status != AuthStatus.authenticated) {
        return false;
      }
      state = AsyncValue.data(
        current.copyWith(
          ownerName: name.trim(),
          operation: AuthOperation.idle,
        ),
      );
      return true;
    } catch (_) {
      final current = state.asData?.value;
      if (current == null || current.status != AuthStatus.authenticated) {
        return false;
      }
      state = AsyncValue.data(
        current.copyWith(
          operation: AuthOperation.idle,
          errorMessage: 'Name update failed.',
        ),
      );
      return false;
    }
  }

  Future<void> login(String password) async {
    final prev = state.asData?.value ??
        AuthState(
          status: AuthStatus.unauthenticated,
          hasOwner: await _authService.hasOwnerAccount(),
          ownerName: await _authService.ownerName(),
        );

    if (prev.operation != AuthOperation.idle) return;

    state = AsyncValue.data(prev.copyWith(
      status: AuthStatus.authenticating,
      operation: AuthOperation.authenticating,
      errorMessage: null,
    ));

    try {
      final success = await _authService.verifyPassword(password);
      if (!success) {
        state = AsyncValue.data(prev.copyWith(
          status: AuthStatus.unauthenticated,
          operation: AuthOperation.idle,
          errorMessage: 'Invalid password. Please try again.',
        ));
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
      if (e is! AuthException) {
        state = AsyncValue.data(prev.copyWith(
          status: AuthStatus.unauthenticated,
          operation: AuthOperation.idle,
          errorMessage: 'Authentication failed.',
        ));
      }
      rethrow;
    }
  }

  void logout() {
    final current = state.asData?.value;
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
