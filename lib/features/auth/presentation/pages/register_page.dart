import 'package:flutter/material.dart';

import 'package:iot_manager/app/routes.dart';

import 'package:iot_manager/core/constants/auth_strings.dart';
import 'package:iot_manager/core/utils/validators.dart';
import 'package:iot_manager/core/widgets/app_background.dart';
import 'package:iot_manager/core/widgets/app_text_field.dart';
import 'package:iot_manager/core/widgets/glass_card.dart';
import 'package:iot_manager/core/widgets/primary_button.dart';

import 'package:iot_manager/features/auth/presentation/controllers/register_controller.dart';
import 'package:iot_manager/features/auth/presentation/widgets/auth_brand_header.dart';
import 'package:iot_manager/features/auth/presentation/widgets/auth_footer.dart';
import 'package:iot_manager/features/auth/presentation/widgets/auth_header.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();

  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  final confirm = TextEditingController();

  late final RegisterController controller;

  bool hidePass = true;
  bool hideConfirm = true;
  bool acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    controller = RegisterController.create();
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
    firstName.dispose();
    lastName.dispose();
    email.dispose();
    pass.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> onRegisterPressed() async {
    FocusScope.of(context).unfocus();

    if (!(formKey.currentState?.validate() ?? false)) return;

    if (!acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AuthStrings.terms),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ok = await controller.register(
      firstName: firstName.text,
      lastName: lastName.text,
      email: email.text,
      password: pass.text,
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AuthStrings.createAcount),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.authGate, (_) => false,
      );
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
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const AuthBrandHeader(),
                  const SizedBox(height: 18),
                  GlassCard(
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AuthHeader(
                            title: AuthStrings.registerTitle,
                            subtitle: AuthStrings.registerSubtitle,
                          ),
                          const SizedBox(height: 18),
                          AppTextField(
                            controller: firstName,
                            label: AuthStrings.firstName,
                            validator: Validators.firstName,
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: lastName,
                            label: AuthStrings.lastName,
                            validator: Validators.lastName,
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: email,
                            label: AuthStrings.email,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.email,
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: pass,
                            label: AuthStrings.password,
                            obscureText: hidePass,
                            validator: Validators.password,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() => hidePass = !hidePass);
                              },
                              icon: Icon(
                                hidePass ? Icons.visibility : Icons.visibility_off,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          AppTextField(
                            controller: confirm,
                            label: AuthStrings.confirmPassword,
                            obscureText: hideConfirm,
                            validator: (v) =>
                                Validators.confirmPassword(v, pass.text),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() => hideConfirm = !hideConfirm,);
                              },
                              icon: Icon(
                                hideConfirm ? Icons.visibility : Icons.visibility_off,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          CheckboxListTile(
                            value: acceptedTerms,
                            onChanged: (v) {
                              setState(() => acceptedTerms = v ?? false);
                            },
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              AuthStrings.acceptTerms,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontSize: 12.5),
                            ),
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            text: AuthStrings.signUp,
                            loading: controller.loading,
                            icon: Icons.person_add,
                            onPressed: controller.loading ? null : onRegisterPressed,
                          ),
                          const SizedBox(height: 10),
                          AuthFooter(
                            text: AuthStrings.haveAccount,
                            actionText: AuthStrings.goLogin,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}