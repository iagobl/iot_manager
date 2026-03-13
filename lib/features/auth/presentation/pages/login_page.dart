import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/auth_strings.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_brand_header.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/utils/validators.dart';

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

  bool loading = false;
  bool hidePass = true;

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> onLoginPressed() async {
    FocusScope.of(context).unfocus();

    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => loading = true);

    try {
      //Aquí voy a llamar a lógica de llamar a backend para hacer login


    } finally {
      if (mounted) {setState(() => loading = false);}
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
                  const AppBrandHeader(),
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
                              icon: Icon(hidePass ? Icons.visibility
                                  : Icons.visibility_off,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: loading ? null : () {
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
                            loading: loading,
                            icon: Icons.login,
                            onPressed: onLoginPressed,
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