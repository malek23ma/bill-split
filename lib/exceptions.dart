class AppException implements Exception {
  final String message;
  final String? code;
  AppException(this.message, {this.code});
  @override
  String toString() => message;
}

class AuthException extends AppException {
  AuthException(super.message, {super.code});
}

class SyncException extends AppException {
  SyncException(super.message, {super.code});
}

class ScanException extends AppException {
  ScanException(super.message, {super.code});
}
