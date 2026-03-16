class AppFailure {
  final String message;
  const AppFailure(this.message);
}

class AuthFailure extends AppFailure {
  const AuthFailure(super.message);
}

class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message);
}

class TimeoutFailure extends AppFailure {
  const TimeoutFailure(super.message);
}

class ServerFailure extends AppFailure {
  const ServerFailure(super.message);
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

class BluetoothFailure extends AppFailure {
  const BluetoothFailure(super.message);
}

class DeviceFailure extends AppFailure {
  const DeviceFailure(super.message);
}

class UnknownFailure extends AppFailure {
  const UnknownFailure(super.message);
}