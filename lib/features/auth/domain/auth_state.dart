enum AuthStatus {
  initializing,
  initializationFailed,
  unauthenticated,
  authenticating,
  authenticated,
}

enum AuthOperation {
  idle,
  settingUpOwner,
  updatingProfile,
  authenticating,
}

class AuthState {
  const AuthState({
    required this.status,
    required this.hasOwner,
    this.ownerName,
    this.operation = AuthOperation.idle,
    this.errorMessage,
  });

  final AuthStatus status;
  final bool hasOwner;
  final String? ownerName;
  final AuthOperation operation;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    bool? hasOwner,
    Object? ownerName = const Object(),
    AuthOperation? operation,
    Object? errorMessage = const Object(),
  }) {
    return AuthState(
      status: status ?? this.status,
      hasOwner: hasOwner ?? this.hasOwner,
      ownerName: identical(ownerName, const Object())
          ? this.ownerName
          : (ownerName as String?),
      operation: operation ?? this.operation,
      errorMessage: identical(errorMessage, const Object())
          ? this.errorMessage
          : (errorMessage as String?),
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
