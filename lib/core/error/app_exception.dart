class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

class AuthAppException extends AppException {
  const AuthAppException(super.message);
}

class NetworkAppException extends AppException {
  const NetworkAppException(super.message);
}

class TimeoutAppException extends AppException {
  const TimeoutAppException(super.message);
}

class ServerAppException extends AppException {
  const ServerAppException(super.message);
}

class UnknownAppException extends AppException {
  const UnknownAppException(super.message);
}

class ValidationAppException extends AppException {
  const ValidationAppException(super.message);
}