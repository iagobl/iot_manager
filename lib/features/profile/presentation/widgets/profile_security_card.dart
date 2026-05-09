import 'package:flutter/material.dart';
import 'package:iot_manager/core/widgets/glass_card.dart';
import 'package:iot_manager/core/widgets/primary_button.dart';

class ProfileSecurityCard extends StatelessWidget {
  const ProfileSecurityCard({
    super.key,
    required this.showPasswordSection,
    required this.obscureCurrentPassword,
    required this.obscureNewPassword,
    required this.obscureConfirmPassword,
    required this.changingPassword,
    required this.requestingPasswordReset,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmNewPasswordController,
    required this.onToggleSection,
    required this.onToggleCurrentPasswordVisibility,
    required this.onToggleNewPasswordVisibility,
    required this.onToggleConfirmPasswordVisibility,
    required this.onChangePassword,
    required this.onRequestPasswordReset,
  });

  final bool showPasswordSection;
  final bool obscureCurrentPassword;
  final bool obscureNewPassword;
  final bool obscureConfirmPassword;
  final bool changingPassword;
  final bool requestingPasswordReset;
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmNewPasswordController;
  final VoidCallback onToggleSection;
  final VoidCallback onToggleCurrentPasswordVisibility;
  final VoidCallback onToggleNewPasswordVisibility;
  final VoidCallback onToggleConfirmPasswordVisibility;
  final VoidCallback onChangePassword;
  final VoidCallback onRequestPasswordReset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seguridad',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800,),
                    ),
                    const SizedBox(height: 4),
                    Text('Cambia tu contraseña o solicita un enlace de recuperación.',
                      style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant,),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: changingPassword || requestingPasswordReset
                    ? null
                    : onToggleSection,
                icon: Icon(
                  showPasswordSection
                      ? Icons.expand_less_rounded
                      : Icons.lock_outline_rounded,
                ),
                label: Text(showPasswordSection ? 'Ocultar' : 'Cambiar'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.mark_email_read_rounded,
                  color: cs.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Si no recuerdas la contraseña actual, puedes recibir un enlace de recuperación en tu correo.',
                    style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: changingPassword || requestingPasswordReset ? null
                      : onRequestPasswordReset,
                  child: requestingPasswordReset ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ) : const Text('Enviar enlace'),
                ),
              ],
            ),
          ),
          if (showPasswordSection) ...[
            const SizedBox(height: 16),
            TextField(
              controller: currentPasswordController,
              obscureText: obscureCurrentPassword,
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                prefixIcon: const Icon(Icons.lock_clock_rounded),
                suffixIcon: IconButton(
                  onPressed: onToggleCurrentPasswordVisibility,
                  icon: Icon(obscureCurrentPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: newPasswordController,
              obscureText: obscureNewPassword,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  onPressed: onToggleNewPasswordVisibility,
                  icon: Icon(obscureNewPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: confirmNewPasswordController,
              obscureText: obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Repetir nueva contraseña',
                prefixIcon: const Icon(Icons.verified_user_rounded),
                suffixIcon: IconButton(
                  onPressed: onToggleConfirmPasswordVisibility,
                  icon: Icon(obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Actualizar contraseña',
              icon: Icons.lock_reset_rounded,
              loading: changingPassword,
              onPressed: onChangePassword,
            ),
          ],
        ],
      ),
    );
  }
}
