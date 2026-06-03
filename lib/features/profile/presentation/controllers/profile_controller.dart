import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:iot_manager/features/profile/domain/entities/profile_entity.dart';
import 'package:iot_manager/features/profile/domain/repositories/profile_repository.dart';
import 'package:iot_manager/features/profile/domain/usecases/change_password.dart';
import 'package:iot_manager/features/profile/domain/usecases/create_avatar_signed_url.dart';
import 'package:iot_manager/features/profile/domain/usecases/get_current_profile.dart';
import 'package:iot_manager/features/profile/domain/usecases/request_password_reset.dart';
import 'package:iot_manager/features/profile/domain/usecases/update_basic_profile.dart';
import 'package:iot_manager/features/profile/domain/usecases/update_unit_preferences.dart';
import 'package:iot_manager/features/profile/domain/usecases/upload_avatar.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({
    ProfileRepository? repository,
    GetCurrentProfile? getCurrentProfile,
    UpdateBasicProfile? updateBasicProfile,
    UpdateUnitPreferences? updateUnitPreferences,
    UploadAvatar? uploadAvatar,
    CreateAvatarSignedUrl? createAvatarSignedUrl,
    ChangePassword? changePassword,
    RequestPasswordReset? requestPasswordReset,
  }) : this._(
    repository ?? ProfileRepositoryImpl(),
    getCurrentProfile: getCurrentProfile,
    updateBasicProfile: updateBasicProfile,
    updateUnitPreferences: updateUnitPreferences,
    uploadAvatar: uploadAvatar,
    createAvatarSignedUrl: createAvatarSignedUrl,
    changePassword: changePassword,
    requestPasswordReset: requestPasswordReset,
  );

  ProfileController._(
      ProfileRepository resolvedRepository, {
        GetCurrentProfile? getCurrentProfile,
        UpdateBasicProfile? updateBasicProfile,
        UpdateUnitPreferences? updateUnitPreferences,
        UploadAvatar? uploadAvatar,
        CreateAvatarSignedUrl? createAvatarSignedUrl,
        ChangePassword? changePassword,
        RequestPasswordReset? requestPasswordReset,
      })  : repository = resolvedRepository,
        getCurrentProfile =getCurrentProfile ?? GetCurrentProfile(resolvedRepository),
        updateBasicProfile =updateBasicProfile ?? UpdateBasicProfile(resolvedRepository),
        updateUnitPreferences =updateUnitPreferences ?? UpdateUnitPreferences(resolvedRepository),
        uploadAvatar = uploadAvatar ?? UploadAvatar(resolvedRepository),
        createAvatarSignedUrl =createAvatarSignedUrl ?? CreateAvatarSignedUrl(resolvedRepository),
        changePassword = changePassword ?? ChangePassword(resolvedRepository),
        requestPasswordReset =requestPasswordReset ?? RequestPasswordReset(resolvedRepository);

  final ProfileRepository repository;
  final GetCurrentProfile getCurrentProfile;
  final UpdateBasicProfile updateBasicProfile;
  final UpdateUnitPreferences updateUnitPreferences;
  final UploadAvatar uploadAvatar;
  final CreateAvatarSignedUrl createAvatarSignedUrl;
  final ChangePassword changePassword;
  final RequestPasswordReset requestPasswordReset;

  bool loading = false;
  bool saving = false;
  bool uploadingAvatar = false;
  bool changingPassword = false;
  bool requestingPasswordReset = false;
  bool editMode = false;

  String? error;
  ProfileEntity? profile;

  bool get hasError => error != null && error!.trim().isNotEmpty;

  void clearError() {
    error = null;
  }

  void setMappedError(Object error) {
    this.error = ErrorMapper.mapFailure(
      ErrorMapper.mapException(error),
    ).message;
  }

  Future<void> load() async {
    loading = true;
    clearError();
    notifyListeners();

    try {
      profile = await getCurrentProfile();
    } catch (e) {
      setMappedError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setEditMode(bool value) {
    editMode = value;
    notifyListeners();
  }

  Future<String> saveBasicProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final trimmedFirstName = firstName.trim();
    final trimmedLastName = lastName.trim();
    final trimmedEmail = email.trim();

    if (trimmedFirstName.isEmpty) {
      const ex = ValidationAppException('Introduce el nombre.');
      setMappedError(ex);
      notifyListeners();
      throw ex;
    }

    if (trimmedLastName.isEmpty) {
      const ex = ValidationAppException('Introduce los apellidos.');
      setMappedError(ex);
      notifyListeners();
      throw ex;
    }

    if (!isValidEmail(trimmedEmail)) {
      const ex = ValidationAppException('Introduce un correo válido.');
      setMappedError(ex);
      notifyListeners();
      throw ex;
    }

    saving = true;
    clearError();
    notifyListeners();

    try {
      await updateBasicProfile(
        firstName: trimmedFirstName,
        lastName: trimmedLastName,
        email: trimmedEmail,
      );

      await load();
      editMode = false;
      notifyListeners();

      return 'Perfil actualizado correctamente.';
    } catch (e) {
      setMappedError(e);
      notifyListeners();
      throw ErrorMapper.mapException(e);
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<String> updateUnitPreference({required String key, required String value}) async {
    if (profile == null) {
      const ex = ValidationAppException('No se pudo cargar el perfil.');
      setMappedError(ex);
      notifyListeners();
      throw ex;
    }

    final updated = Map<String, String>.from(profile!.unitPreferences)..[key] = value;

    clearError();
    notifyListeners();

    try {
      await updateUnitPreferences(updated);
      profile = profile!.copyWith(unitPreferences: updated);
      notifyListeners();
      return 'Preferencias de unidades actualizadas.';
    } catch (e) {
      setMappedError(e);
      notifyListeners();
      throw ErrorMapper.mapException(e);
    }
  }

  Future<String> uploadAvatarFile({required List<int> bytes, required String extension}) async {
    if (bytes.isEmpty) {
      const ex = ValidationAppException('La imagen seleccionada está vacía.');
      setMappedError(ex);
      notifyListeners();
      throw ex;
    }

    uploadingAvatar = true;
    clearError();
    notifyListeners();

    try {
      final path = await uploadAvatar(bytes: Uint8List.fromList(bytes), extension: extension);
      final signedUrl = await createAvatarSignedUrl(path);

      if (profile != null) {
        profile = profile!.copyWith(avatarPath: path, avatarSignedUrl: signedUrl);
      }

      notifyListeners();
      return 'Foto de perfil actualizada.';
    } catch (e) {
      setMappedError(e);
      notifyListeners();
      throw ErrorMapper.mapException(e);
    } finally {
      uploadingAvatar = false;
      notifyListeners();
    }
  }

  Future<String> changeUserPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    final current = currentPassword.trim();
    final next = newPassword.trim();
    final confirm = confirmNewPassword.trim();

    if (current.isEmpty) {
      const ex = ValidationAppException('Introduce tu contraseña actual.');
      setMappedError(ex);
      notifyListeners();
      throw ex;
    }

    if (next.length < 6) {
      const ex = ValidationAppException('La nueva contraseña debe tener al menos 6 caracteres.');
      setMappedError(ex);
      notifyListeners();
      throw ex;
    }

    if (next != confirm) {
      const ex = ValidationAppException('La nueva contraseña y su confirmación no coinciden.');
      setMappedError(ex);
      notifyListeners();
      throw ex;
    }

    if (current == next) {
      const ex = ValidationAppException('La nueva contraseña no puede ser igual a la actual.');
      setMappedError(ex);
      notifyListeners();
      throw ex;
    }

    changingPassword = true;
    clearError();
    notifyListeners();

    try {
      await changePassword(
        currentPassword: current,
        newPassword: next,
      );

      return 'Contraseña actualizada correctamente.';
    } catch (e) {
      setMappedError(e);
      notifyListeners();
      throw ErrorMapper.mapException(e);
    } finally {
      changingPassword = false;
      notifyListeners();
    }
  }

  Future<String> sendPasswordRecoveryEmail({
    required String email,
    String? redirectTo,
  }) async {
    final trimmedEmail = email.trim();

    if (!isValidEmail(trimmedEmail)) {
      const ex = ValidationAppException('Introduce un correo válido para recuperar la contraseña.');
      setMappedError(ex);
      notifyListeners();
      throw ex;
    }

    requestingPasswordReset = true;
    clearError();
    notifyListeners();

    try {
      await requestPasswordReset(
        email: trimmedEmail,
        redirectTo: redirectTo,
      );

      return 'Te hemos enviado un enlace de recuperación a $trimmedEmail.';
    } catch (e) {
      setMappedError(e);
      notifyListeners();
      throw ErrorMapper.mapException(e);
    } finally {
      requestingPasswordReset = false;
      notifyListeners();
    }
  }

  bool isValidEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }
}
