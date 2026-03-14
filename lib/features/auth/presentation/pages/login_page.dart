import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/auth_strings.dart';
import '../../../../core/widgets/app_background.dart';
import '../widgets/auth_brand_header.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/utils/validators.dart';

import '../controllers/login_controller.dart';
import '../widgets/auth_footer.dart';
import '../widgets/auth_header.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final pass = TextEditingController();

  late final LoginController controller;

  bool hidePass = true;

  @override
  void initState() {
    super.initState();
    controller = LoginController.create();
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
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> onLoginPressed() async {
    FocusScope.of(context).unfocus();

    if (!(formKey.currentState?.validate() ?? false)) return;

    final ok = await controller.login(
      email: email.text,
      password: pass.text,
    );

    if (!mounted) return;
    if (ok) {
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
                            title: AuthStrings.loginTitle,
                            subtitle: 'Accede a tu cuenta.',
                          ),
                          const SizedBox(height: 18),
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
                            textInputAction: TextInputAction.done,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() => hidePass = !hidePass);
                              },
                              icon: Icon(
                                hidePass ? Icons.visibility : Icons.visibility_off,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: controller.loading ? null : () {
                                Navigator.of(context).pushNamed(
                                  Routes.forgotPassword,
                                );
                              },
                              child: const Text(AuthStrings.forgotPassword),
                            ),
                          ),
                          const SizedBox(height: 6),
                          PrimaryButton(
                            text: AuthStrings.signIn,
                            loading: controller.loading,
                            icon: Icons.login,
                            onPressed: controller.loading ? null : onLoginPressed,
                          ),
                          const SizedBox(height: 10),
                          AuthFooter(
                            text: AuthStrings.noAccount,
                            actionText: AuthStrings.goRegister,
                            onTap: () {
                              Navigator.of(context).pushNamed(Routes.register);
                            },
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