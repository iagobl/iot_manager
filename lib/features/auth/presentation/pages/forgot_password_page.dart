import 'package:flutter/material.dart';

import 'package:iot_manager/core/constants/auth_strings.dart';
import 'package:iot_manager/core/utils/validators.dart';
import 'package:iot_manager/core/widgets/app_background.dart';
import 'package:iot_manager/core/widgets/app_text_field.dart';
import 'package:iot_manager/core/widgets/glass_card.dart';
import 'package:iot_manager/core/widgets/primary_button.dart';

import 'package:iot_manager/features/auth/presentation/controllers/forgot_password_controller.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();

  late final ForgotPasswordController controller;

  @override
  void initState() {
    super.initState();
    controller = ForgotPasswordController.create();
    controller.addListener(onControllerChanged);
  }

  void onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(onControllerChanged);
    controller.dispose();
    emailCtrl.dispose();
    super.dispose();
  }

  Future<void> onSendPressed() async {
    FocusScope.of(context).unfocus();

    if (!(formKey.currentState?.validate() ?? false)) return;

    final ok = await controller.sendRecoveryEmail(
      email: emailCtrl.text,
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AuthStrings.recoveryEmail),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();
      return;
    }

    final message = controller.errorMessage;

    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: AppBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: GlassCard(
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            splashRadius: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AuthStrings.recoverPasswordTitle,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AuthStrings.recoverPasswordSubtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 22),
                      AppTextField(
                        controller: emailCtrl,
                        label: AuthStrings.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 22),
                      PrimaryButton(
                        text: AuthStrings.sendRecoveryEmail,
                        loading: controller.loading,
                        icon: Icons.mark_email_read,
                        onPressed: controller.loading ? null : onSendPressed,
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