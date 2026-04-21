import 'package:flutter/foundation.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/repositories/devices_repository_impl.dart';
import 'package:iot_manager/features/devices/domain/usecases/fetch_device_ownership.dart';
import 'package:iot_manager/features/devices/domain/usecases/get_device_shares.dart';
import 'package:iot_manager/features/devices/domain/usecases/get_profiles_by_ids.dart';
import 'package:iot_manager/features/devices/domain/usecases/invite_device_share_by_email.dart';
import 'package:iot_manager/features/devices/domain/usecases/leave_shared_device.dart';
import 'package:iot_manager/features/devices/domain/usecases/revoke_device_share.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceShareController extends ChangeNotifier {
  DeviceShareController({
    required this.deviceId,
    required this.deviceName,
    DevicesRemoteDatasource? remoteDatasource,
    SupabaseClient? supabase,
  })  : fetchDeviceOwnership = FetchDeviceOwnership(
    DevicesRepositoryImpl(remoteDatasource ?? DevicesRemoteDatasource()),
  ),
        getDeviceShares = GetDeviceShares(
          DevicesRepositoryImpl(remoteDatasource ?? DevicesRemoteDatasource()),
        ),
        getProfilesByIds = GetProfilesByIds(
          DevicesRepositoryImpl(remoteDatasource ?? DevicesRemoteDatasource()),
        ),
        inviteDeviceShareByEmail = InviteDeviceShareByEmail(
          DevicesRepositoryImpl(remoteDatasource ?? DevicesRemoteDatasource()),
        ),
        revokeDeviceShare = RevokeDeviceShare(
          DevicesRepositoryImpl(remoteDatasource ?? DevicesRemoteDatasource()),
        ),
        leaveSharedDeviceUseCase = LeaveSharedDevice(
          DevicesRepositoryImpl(remoteDatasource ?? DevicesRemoteDatasource()),
        ),
        supabase = supabase ?? Supabase.instance.client;

  final String deviceId;
  final String deviceName;
  final FetchDeviceOwnership fetchDeviceOwnership;
  final GetDeviceShares getDeviceShares;
  final GetProfilesByIds getProfilesByIds;
  final InviteDeviceShareByEmail inviteDeviceShareByEmail;
  final RevokeDeviceShare revokeDeviceShare;
  final LeaveSharedDevice leaveSharedDeviceUseCase;
  final SupabaseClient supabase;

  bool loading = false;
  bool revoking = false;
  bool invitingByEmail = false;
  bool leaving = false;
  bool isOwner = false;
  String? error;

  List<DeviceShareEntry> entries = [];

  String get currentUserId => supabase.auth.currentUser?.id ?? '';
  bool get hasError => error != null && error!.trim().isNotEmpty;

  void clearError() {
    error = null;
  }

  void setMappedError(Object error) {
    this.error = ErrorMapper.mapFailure(ErrorMapper.mapException(error)).message;
  }

  Future<void> load() async {
    loading = true;
    clearError();
    notifyListeners();

    try {
      if (deviceId.trim().isEmpty) {
        throw const ValidationAppException('No se ha encontrado un identificador válido del dispositivo.');
      }

      final deviceRow = await fetchDeviceOwnership(deviceId);
      if (deviceRow == null) {
        throw const ValidationAppException('No se encontró el dispositivo.');
      }

      final ownerId = (deviceRow['owner_id'] ?? '').toString();
      isOwner = ownerId == currentUserId;

      final allRows = await getDeviceShares(deviceId);
      final rows = isOwner ? allRows : allRows.where((row) {
        final sharedWithUserId = (row['shared_with_user_id'] ?? '').toString();
        return sharedWithUserId == currentUserId;
      }).toList();

      final sharedUserIds = rows
          .map((e) => e['shared_with_user_id']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      final profiles = await getProfilesByIds(sharedUserIds);
      final profileNames = <String, String>{};

      for (final raw in profiles) {
        final id = (raw['id'] ?? '').toString();
        final first = (raw['first_name'] ?? '').toString().trim();
        final last = (raw['last_name'] ?? '').toString().trim();
        final email = (raw['email'] ?? '').toString().trim();
        final fullName = '$first $last'.trim();

        profileNames[id] =
        fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email : id);
      }

      entries = rows.map((row) {
        final sharedWithUserId = row['shared_with_user_id']?.toString();
        final sharedWithEmail = row['shared_with_email']?.toString();

        return DeviceShareEntry(
          id: (row['id'] ?? '').toString(),
          deviceId: (row['device_id'] ?? '').toString(),
          ownerId: (row['owner_id'] ?? '').toString(),
          sharedWithUserId: sharedWithUserId,
          sharedWithEmail: sharedWithEmail,
          sharedWithDisplayName: sharedWithUserId == null
              ? (sharedWithEmail ?? 'Invitación pendiente')
              : (profileNames[sharedWithUserId] ??
              sharedWithEmail ??
              sharedWithUserId),
          status: (row['status'] ?? 'pending').toString(),
          createdAt: _parseDate(row['created_at']),
          acceptedAt: _parseDate(row['accepted_at']),
          revokedAt: _parseDate(row['revoked_at']),
        );
      }).toList();

      clearError();
    } catch (e) {
      setMappedError(e);
      entries = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String> inviteByEmail(String email) async {
    if (!isOwner) {
      final error = const ValidationAppException('Solo el propietario puede invitar usuarios.');

      setMappedError(error);
      notifyListeners();
      throw error;
    }

    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      final error = const ValidationAppException('Introduce un correo válido.');

      setMappedError(error);
      notifyListeners();
      throw error;
    }

    invitingByEmail = true;
    clearError();
    notifyListeners();

    try {
      await inviteDeviceShareByEmail(
        deviceId: deviceId,
        email: normalized,
      );
      await load();
      return 'Invitación enviada correctamente.';
    } catch (e) {
      final mapped = _normalizeShareException(e);
      setMappedError(mapped);
      notifyListeners();
      throw mapped;
    } finally {
      invitingByEmail = false;
      notifyListeners();
    }
  }

  Future<String> revokeShare(String shareId) async {
    final normalizedId = shareId.trim();

    if (!isOwner) {
      final error = const ValidationAppException('Solo el propietario puede revocar accesos.');
      setMappedError(error);
      notifyListeners();
      throw error;
    }

    if (normalizedId.isEmpty) {
      final error = const ValidationAppException('No se ha encontrado un acceso compartido válido.');
      setMappedError(error);
      notifyListeners();
      throw error;
    }

    revoking = true;
    clearError();
    notifyListeners();

    try {
      await revokeDeviceShare(normalizedId);
      await load();
      return 'Acceso revocado correctamente.';
    } catch (e) {
      final mapped = ErrorMapper.mapException(e);
      setMappedError(mapped);
      notifyListeners();
      throw mapped;
    } finally {
      revoking = false;
      notifyListeners();
    }
  }

  Future<String> leaveSharedDevice(String shareId) async {
    final normalizedId = shareId.trim();

    if (isOwner) {
      final error = const ValidationAppException('El propietario no puede usar esta acción.');
      setMappedError(error);
      notifyListeners();
      throw error;
    }

    if (normalizedId.isEmpty) {
      final error = const ValidationAppException('No se ha encontrado un acceso compartido válido.');
      setMappedError(error);
      notifyListeners();
      throw error;
    }

    leaving = true;
    clearError();
    notifyListeners();

    try {
      await leaveSharedDeviceUseCase(normalizedId);
      await load();
      return 'Has dejado de tener acceso a este dispositivo.';
    } catch (e) {
      final mapped = ErrorMapper.mapException(e);
      setMappedError(mapped);
      notifyListeners();
      throw mapped;
    } finally {
      leaving = false;
      notifyListeners();
    }
  }

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  AppException _normalizeShareException(Object error) {
    final message = ErrorMapper.mapFailure(ErrorMapper.mapException(error))
        .message
        .toLowerCase();

    if (message.contains('ti mismo')) {
      return const ValidationAppException('No puedes compartir el dispositivo contigo mismo.');
    }
    if (message.contains('no existe') || message.contains('correo')) {
      return const ValidationAppException('No existe ningún usuario registrado con ese correo.');
    }
    if (message.contains('ya tiene acceso') ||
        message.contains('ya fue invitado') ||
        message.contains('duplicate') ||
        message.contains('duplic')) {
      return const ValidationAppException('Ese usuario ya tiene acceso o ya fue invitado.');
    }

    return ErrorMapper.mapException(error);
  }
}

class DeviceShareEntry {
  const DeviceShareEntry({
    required this.id,
    required this.deviceId,
    required this.ownerId,
    required this.sharedWithUserId,
    required this.sharedWithEmail,
    required this.sharedWithDisplayName,
    required this.status,
    required this.createdAt,
    required this.acceptedAt,
    required this.revokedAt,
  });

  final String id;
  final String deviceId;
  final String ownerId;
  final String? sharedWithUserId;
  final String? sharedWithEmail;
  final String? sharedWithDisplayName;
  final String status;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRevoked => status == 'revoked';
  bool get isRejected => status == 'rejected';
}
