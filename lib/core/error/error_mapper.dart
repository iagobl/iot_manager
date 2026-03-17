import 'dart:async';
import 'dart:io';

import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/app_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorMapper {
  static AppException mapException(Object error) {
    if (error is AppException) return error;

    if (error is TimeoutException) {
      return const TimeoutAppException(
        'La operación tardó demasiado en completarse.',
      );
    }

    if (error is SocketException || error is HttpException) {
      return const NetworkAppException(
        'No se pudo establecer la conexión de red.',
      );
    }

    if (error is AuthException) {
      final message = error.message.toLowerCase();

      if (message.contains('invalid login credentials')) {
        return const AuthAppException('Correo o contraseña incorrectos.');
      }

      if (message.contains('email not confirmed')) {
        return const AuthAppException(
          'Debes confirmar tu correo electrónico.',
        );
      }

      if (message.contains('user already registered')) {
        return const AuthAppException('Ese correo ya está registrado.');
      }

      if (message.contains('signup is disabled')) {
        return const AuthAppException('El registro está deshabilitado.');
      }

      return AuthAppException(error.message);
    }

    if (error is PostgrestException) {
      return DatabaseAppException(error.message);
    }

    if (error is StorageException) {
      return ServerAppException(error.message);
    }

    return const UnknownAppException('Ha ocurrido un error inesperado.');
  }

  static AppFailure mapFailure(Object error) {
    if (error is AppFailure) return error;

    if (error is TimeoutAppException) {
      return TimeoutFailure(error.message);
    }

    if (error is NetworkAppException) {
      return NetworkFailure(error.message);
    }

    if (error is ValidationAppException) {
      return ValidationFailure(error.message);
    }

    if (error is BluetoothAppException) {
      return BluetoothFailure(error.message);
    }

    if (error is DeviceAppException) {
      return DeviceFailure(error.message);
    }

    if (error is DatabaseAppException) {
      return DatabaseFailure(error.message);
    }

    if (error is ServerAppException) {
      return ServerFailure(error.message);
    }

    if (error is AuthAppException) {
      return AuthFailure(error.message);
    }

    if (error is AppException) {
      return UnknownFailure(error.message);
    }

    return const UnknownFailure('Ha ocurrido un error inesperado.');
  }
}