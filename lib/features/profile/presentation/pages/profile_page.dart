import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iot_manager/core/widgets/app_background.dart';
import 'package:iot_manager/core/widgets/glass_card.dart';
import 'package:iot_manager/features/profile/presentation/controllers/profile_controller.dart';
import 'package:iot_manager/features/profile/presentation/widgets/profile_header_card.dart';
import 'package:iot_manager/features/profile/presentation/widgets/profile_personal_info_card.dart';
import 'package:iot_manager/features/profile/presentation/widgets/profile_security_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  late final ProfileController controller;
  final ImagePicker imagePicker = ImagePicker();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();

  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmNewPasswordController = TextEditingController();

  bool hydratedFields = false;
  bool showPasswordSection = false;
  bool obscureCurrentPassword = true;
  bool obscureNewPassword = true;
  bool obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    controller = ProfileController()..addListener(onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.load();
    });
  }

  @override
  void dispose() {
    controller.removeListener(onControllerChanged);
    controller.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmNewPasswordController.dispose();
    super.dispose();
  }

  void onControllerChanged() {
    final profile = controller.profile;

    if (profile != null && !hydratedFields) {
      firstNameController.text = profile.firstName;
      lastNameController.text = profile.lastName;
      emailController.text = profile.email;
      hydratedFields = true;
    }

    if (!mounted) return;
    setState(() {});
  }

  void resetFieldsFromProfile() {
    final profile = controller.profile;
    if (profile == null) return;

    firstNameController.text = profile.firstName;
    lastNameController.text = profile.lastName;
    emailController.text = profile.email;
  }

  void clearPasswordFields() {
    currentPasswordController.clear();
    newPasswordController.clear();
    confirmNewPasswordController.clear();
  }

  Future<void> showMessage(String message) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> saveBasicProfile() async {
    try {
      final message = await controller.saveBasicProfile(
        firstName: firstNameController.text,
        lastName: lastNameController.text,
        email: emailController.text,
      );

      await showMessage(message);
    } catch (_) {
      await showMessage(
        controller.error ?? 'No se pudo actualizar el perfil.',
      );
    }
  }

  Future<void> changePassword() async {
    try {
      final message = await controller.changeUserPassword(
        currentPassword: currentPasswordController.text,
        newPassword: newPasswordController.text,
        confirmNewPassword: confirmNewPasswordController.text,
      );

      clearPasswordFields();

      setState(() {
        showPasswordSection = false;
      });

      await showMessage(message);
    } catch (_) {
      await showMessage(
        controller.error ?? 'No se pudo actualizar la contraseña.',
      );
    }
  }

  Future<void> requestPasswordReset() async {
    try {
      final message = await controller.sendPasswordRecoveryEmail(
        email: emailController.text,
        redirectTo: 'iotmanager://reset-password',
      );

      await showMessage(message);
    } catch (_) {
      await showMessage(
        controller.error ?? 'No se pudo enviar el enlace de recuperación.',
      );
    }
  }

  Future<void> pickAvatar(ImageSource source) async {
    try {
      final file = await imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final extension = extractExtension(file.path);

      final message = await controller.uploadAvatarFile(
        bytes: bytes,
        extension: extension,
      );

      await showMessage(message);
    } catch (_) {
      await showMessage(
        controller.error ?? 'No se pudo actualizar la foto de perfil.',
      );
    }
  }

  String extractExtension(String path) {
    final lower = path.toLowerCase();

    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.jpeg')) return 'jpeg';

    return 'jpg';
  }

  InputDecoration profileFieldDecoration({
    required BuildContext context,
    required String label,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: cs.surface.withValues(alpha: 0.55),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: cs.primary,
          width: 1.4,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;

    return Scaffold(
      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text('Perfil'),
                centerTitle: false,
                actions: [
                  if (!controller.editMode)
                    TextButton.icon(
                      onPressed: profile == null
                          ? null
                          : () {
                        resetFieldsFromProfile();
                        controller.setEditMode(true);
                      },
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Modificar'),
                    )
                  else ...[
                    IconButton(
                      tooltip: 'Cancelar edición',
                      onPressed: () {
                        resetFieldsFromProfile();
                        clearPasswordFields();

                        setState(() {
                          showPasswordSection = false;
                        });

                        controller.setEditMode(false);
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                    TextButton.icon(
                      onPressed: controller.saving ? null : saveBasicProfile,
                      icon: controller.saving
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        controller.saving ? 'Guardando...' : 'Guardar',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (_) {
                  if (controller.loading && profile == null) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (controller.hasError && profile == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: GlassCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 42,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                controller.error!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: controller.load,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (profile == null) {
                    return const SizedBox.shrink();
                  }

                  return RefreshIndicator(
                    onRefresh: controller.load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        ProfileHeaderCard(
                          profile: profile,
                          editMode: controller.editMode,
                          uploadingAvatar: controller.uploadingAvatar,
                          onCameraTap: () => pickAvatar(ImageSource.camera),
                          onGalleryTap: () => pickAvatar(ImageSource.gallery),
                        ),
                        const SizedBox(height: 18),
                        ProfilePersonalInfoCard(
                          editMode: controller.editMode,
                          saving: controller.saving,
                          firstNameController: firstNameController,
                          lastNameController: lastNameController,
                          emailController: emailController,
                          inputDecorationBuilder: profileFieldDecoration,
                          onSave: saveBasicProfile,
                        ),
                        const SizedBox(height: 18),
                        ProfileSecurityCard(
                          showPasswordSection: showPasswordSection,
                          obscureCurrentPassword: obscureCurrentPassword,
                          obscureNewPassword: obscureNewPassword,
                          obscureConfirmPassword: obscureConfirmPassword,
                          changingPassword: controller.changingPassword,
                          requestingPasswordReset:
                          controller.requestingPasswordReset,
                          currentPasswordController: currentPasswordController,
                          newPasswordController: newPasswordController,
                          confirmNewPasswordController:
                          confirmNewPasswordController,
                          onToggleSection: () {
                            setState(() {
                              showPasswordSection = !showPasswordSection;

                              if (!showPasswordSection) {
                                clearPasswordFields();
                              }
                            });
                          },
                          onToggleCurrentPasswordVisibility: () {
                            setState(() {
                              obscureCurrentPassword =
                              !obscureCurrentPassword;
                            });
                          },
                          onToggleNewPasswordVisibility: () {
                            setState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                          onToggleConfirmPasswordVisibility: () {
                            setState(() {
                              obscureConfirmPassword =
                              !obscureConfirmPassword;
                            });
                          },
                          onChangePassword: changePassword,
                          onRequestPasswordReset: requestPasswordReset,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
