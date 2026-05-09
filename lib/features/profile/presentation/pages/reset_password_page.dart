import 'package:flutter/material.dart';
import 'package:iot_manager/core/widgets/app_background.dart';
import 'package:iot_manager/core/widgets/glass_card.dart';
import 'package:iot_manager/core/widgets/primary_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  static const routeName = '/reset-password';

  @override
  State<ResetPasswordPage> createState() => ResetPasswordPageState();
}

class ResetPasswordPageState extends State<ResetPasswordPage> {
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;
  bool obscureNewPassword = true;
  bool obscureConfirmPassword = true;
  String? error;

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> updatePassword() async {
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (newPassword.length < 6) {
      setState(() {
        error = 'La nueva contraseña debe tener al menos 6 caracteres.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        error = 'Las contraseñas no coinciden.';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña actualizada correctamente.'),
        ),
      );

      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login', (route) => false,
      );
    } on AuthException catch (e) {
      setState(() {
        error = e.message;
      });
    } catch (_) {
      setState(() {
        error = 'No se pudo actualizar la contraseña.';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock_reset_rounded,
                            size: 38,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text('Crear nueva contraseña',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Introduce una nueva contraseña para recuperar el acceso a tu cuenta.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: newPasswordController,
                        obscureText: obscureNewPassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          labelStyle: const TextStyle(
                            fontSize: 12,
                          ),
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                obscureNewPassword = !obscureNewPassword;
                              });
                            },
                            icon: Icon(obscureNewPassword
                                ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => loading ? null : updatePassword(),
                        decoration: InputDecoration(
                          labelText: 'Repetir nueva contraseña',
                          labelStyle: const TextStyle(
                            fontSize: 12,
                          ),
                          prefixIcon: const Icon(Icons.verified_user_rounded),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                obscureConfirmPassword = !obscureConfirmPassword;
                              });
                            },
                            icon: Icon(obscureConfirmPassword
                                  ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.errorContainer.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            error!,
                            style: textTheme.bodySmall?.copyWith(
                              color: cs.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      PrimaryButton(
                        text: 'Actualizar contraseña',
                        icon: Icons.check_rounded,
                        loading: loading,
                        onPressed: updatePassword,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
