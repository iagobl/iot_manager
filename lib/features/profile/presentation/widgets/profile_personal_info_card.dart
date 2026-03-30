import 'package:flutter/material.dart';
import 'package:iot_manager/core/widgets/glass_card.dart';
import 'package:iot_manager/core/widgets/primary_button.dart';
import 'package:iot_manager/features/profile/presentation/widgets/profile_display_field_compact.dart';

class ProfilePersonalInfoCard extends StatelessWidget {
  const ProfilePersonalInfoCard({
    super.key,
    required this.editMode,
    required this.saving,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.inputDecorationBuilder,
    required this.onSave,
  });

  final bool editMode;
  final bool saving;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final InputDecoration Function({
  required BuildContext context,
  required String label,
  required IconData icon,
  }) inputDecorationBuilder;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Información personal',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          editMode ? TextField(
            controller: firstNameController,
            decoration: inputDecorationBuilder(
              context: context,
              label: 'Nombre',
              icon: Icons.badge_rounded,
            ),
          ) : ProfileDisplayFieldCompact(
            label: 'Nombre',
            value: firstNameController.text,
            icon: Icons.badge_rounded,
          ),
          const SizedBox(height: 18),
          editMode ? TextField(
            controller: lastNameController,
            decoration: inputDecorationBuilder(
              context: context,
              label: 'Apellidos',
              icon: Icons.person_rounded,
            ),
          ) : ProfileDisplayFieldCompact(
            label: 'Apellidos',
            value: lastNameController.text,
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: 18),
          editMode ? TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: inputDecorationBuilder(
              context: context,
              label: 'Correo electrónico',
              icon: Icons.alternate_email_rounded,
            ),
          ) : ProfileDisplayFieldCompact(
            label: 'Correo electrónico',
            value: emailController.text,
            icon: Icons.email_rounded,
          ),
          if (editMode) ...[
            const SizedBox(height: 18),
            PrimaryButton(
              text: 'Guardar cambios',
              icon: Icons.save_rounded,
              loading: saving,
              onPressed: onSave,
            ),
          ],
        ],
      ),
    );
  }
}