import 'dart:async';
import 'dart:io';

import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/app_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorMapper {
  static AppException mapException(Object error) {
    if (error is AppException) {
      final remapped = _mapDeviceExceptionFromMessage(
        normalizeMessage(error.message),
      );
      return remapped ?? error;
    }

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
      return mapAuthException(error);
    }

    if (error is PostgrestException) {
      return mapPostgrestException(error);
    }

    if (error is StorageException) {
      return ServerAppException(mapStorageMessage(error.message));
    }

    final normalizedMessage = normalizeMessage(error.toString());
    final mappedDeviceException = _mapDeviceExceptionFromMessage(
      normalizedMessage,
    );

    if (mappedDeviceException != null) {
      return mappedDeviceException;
    }

    if (normalizedMessage.isNotEmpty) {
      return UnknownAppException(mapGenericMessage(normalizedMessage));
    }

    return const UnknownAppException('Ha ocurrido un error inesperado.');
  }

  static AppFailure mapFailure(Object error) {
    if (error is AppFailure) return error;

    if (error is AppException) {
      final remapped = _mapDeviceExceptionFromMessage(
        normalizeMessage(error.message),
      );

      final effectiveError = remapped ?? error;

      if (effectiveError is TimeoutAppException) {
        return TimeoutFailure(effectiveError.message);
      }

      if (effectiveError is NetworkAppException) {
        return NetworkFailure(effectiveError.message);
      }

      if (effectiveError is ValidationAppException) {
        return ValidationFailure(effectiveError.message);
      }

      if (effectiveError is BluetoothAppException) {
        return BluetoothFailure(effectiveError.message);
      }

      if (effectiveError is DeviceSafetyAppException) {
        return DeviceSafetyFailure(effectiveError.message);
      }

      if (effectiveError is DeviceAppException) {
        return DeviceFailure(effectiveError.message);
      }

      if (effectiveError is DatabaseAppException) {
        return DatabaseFailure(effectiveError.message);
      }

      if (effectiveError is ServerAppException) {
        return ServerFailure(effectiveError.message);
      }

      if (effectiveError is AuthAppException) {
        return AuthFailure(effectiveError.message);
      }

      return UnknownFailure(effectiveError.message);
    }

    final normalizedMessage = normalizeMessage(error.toString());
    final mappedDeviceException = _mapDeviceExceptionFromMessage(
      normalizedMessage,
    );
    if (mappedDeviceException != null) {
      return mapFailure(mappedDeviceException);
    }

    if (normalizedMessage.isNotEmpty) {
      return UnknownFailure(mapGenericMessage(normalizedMessage));
    }

    return const UnknownFailure('Ha ocurrido un error inesperado.');
  }

  static AppException mapAuthException(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials')) {
      return const AuthAppException('Correo o contraseña incorrectos.');
    }

    if (message.contains('email not confirmed')) {
      return const AuthAppException('Debes confirmar tu correo electrónico.');
    }

    if (message.contains('user already registered')) {
      return const AuthAppException('Ese correo ya está registrado.');
    }

    if (message.contains('signup is disabled')) {
      return const AuthAppException('El registro está deshabilitado.');
    }

    return AuthAppException(mapGenericMessage(error.message));
  }

  static AppException mapPostgrestException(PostgrestException error) {
    final message = normalizeMessage(error.message);
    final lower = message.toLowerCase();

    if (lower.contains('duplicate key') ||
        lower.contains('already exists') ||
        lower.contains('unique constraint')) {
      return const DatabaseAppException('Ya existe un registro con esos datos.');
    }

    if (lower.contains('row-level security') || lower.contains('permission')) {
      return const DatabaseAppException('No tienes permisos para realizar esta acción.');
    }

    if (lower.contains('foreign key')) {
      return const DatabaseAppException('No se puede completar la acción porque hay datos relacionados.');
    }

    if (lower.contains('violates not-null constraint')) {
      return const DatabaseAppException('Faltan datos obligatorios para completar la operación.');
    }

    return DatabaseAppException(mapGenericMessage(message));
  }

  static DeviceAppException? _mapDeviceExceptionFromMessage(String message) {
    if (message.isEmpty) return null;

    final lower = message.toLowerCase();

    if (containsAny(lower, const [
      'device_blocked_by_incidents',
      'blocked by incidents',
      'device blocked',
    ])) {
      return const DeviceSafetyAppException('El dispositivo está bloqueado por seguridad. Revisa las incidencias activas.');
    }

    if (containsAny(lower, const [
      'overvoltage',
      'over voltage',
      'overvoltage condition present',
    ])) {
      return const DeviceSafetyAppException('No se puede encender el dispositivo, se ha superado límite de tensión.');
    }

    if (containsAny(lower, const [
      'overpower',
      'over power',
      'overpower condition present',
      'max power',
    ])) {
      return const DeviceSafetyAppException('No se puede encender el dispositivo,  se ha superado límite de potencia.');
    }

    if (containsAny(lower, const [
      'overcurrent',
      'over current',
      'overcurrent condition present',
      'max current',
    ])) {
      return const DeviceSafetyAppException('No se puede encender el dispositivo, se ha superado límite de corriente.');
    }

    if (containsAny(lower, const [
      'overtemperature',
      'over temperature',
      'temperature protection',
      'overtemp',
    ])) {
      return const DeviceSafetyAppException('No se puede encender el dispositivo, se ha activado la protección por temperatura.');
    }

    if (containsAny(lower, const [
      'precondition failed',
      'condition present',
      'safety',
      'protection active',
    ])) {
      return const DeviceSafetyAppException('El dispositivo no puede encenderse, tiene una condición de seguridad activa.');
    }

    if (containsAny(lower, const [
      'rpc',
      'switch.set',
      'sys.getstatus',
      'wifi.getstatus',
      'device or resource busy',
      'host lookup failed',
      'connection refused',
      'failed host lookup',
      'network is unreachable',
      'no route to host',
    ])) {
      return const DeviceAppException('No se ha podido completar la acción en el dispositivo. Comprueba que esté conectado y accesible en la red.');
    }
    return null;
  }

  static String mapStorageMessage(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('object not found')) {
      return 'No se ha encontrado el archivo solicitado.';
    }

    if (lower.contains('mime type') || lower.contains('invalid file')) {
      return 'El archivo seleccionado no es válido.';
    }

    return mapGenericMessage(message);
  }

  static String mapGenericMessage(String message) {
    final normalized = normalizeMessage(message);
    final lower = normalized.toLowerCase();

    if (lower.isEmpty) {
      return 'Ha ocurrido un error inesperado.';
    }

    if (lower.contains('timeout')) {
      return 'La operación tardó demasiado en completarse.';
    }

    if (containsAny(lower, const [
      'socketexception',
      'failed host lookup',
      'connection refused',
      'network is unreachable',
      'no route to host',
      'connection closed before full header was received',
    ])) {
      return 'No se pudo establecer la conexión con el dispositivo o con la red.';
    }

    return normalized;
  }

  static String normalizeMessage(String message) {
    var normalized = message.trim();

    if (normalized.startsWith('Exception:')) {
      normalized = normalized.substring('Exception:'.length).trim();
    }

    if (normalized.startsWith('error:')) {
      normalized = normalized.substring('error:'.length).trim();
    }

    return normalized;
  }

  static bool containsAny(String value, List<String> candidates) {
    for (final candidate in candidates) {
      if (value.contains(candidate)) {
        return true;
      }
    }
    return false;
  }
}