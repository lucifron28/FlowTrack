enum AuthStatus {
  initializing,
  unauthenticated,
  authenticating,
  authenticated,
}

class AuthState {
  const AuthState({
    required this.status,
    required this.hasOwner,
    this.ownerName,
  });

  final AuthStatus status;
  final bool hasOwner;
  final String? ownerName;

  AuthState copyWith({
    AuthStatus? status,
    bool? hasOwner,
    String? ownerName,
  }) {
    return AuthState(
      status: status ?? this.status,
      hasOwner: hasOwner ?? this.hasOwner,
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
