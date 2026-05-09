import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:iot_manager/app/app.dart';
import 'package:iot_manager/app/app_navigator.dart';
import 'package:iot_manager/core/config/firebase_options.dart';
import 'package:iot_manager/core/config/supabase_config.dart';
import 'package:iot_manager/features/app_shell/services/push_notification_service.dart';
import 'package:iot_manager/features/profile/presentation/pages/reset_password_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  await PushNotificationService.instance.initialize();

  runApp(const PasswordRecoveryListener(child: MyApp()));
}

class PasswordRecoveryListener extends StatefulWidget {
  const PasswordRecoveryListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<PasswordRecoveryListener> createState() => _PasswordRecoveryListenerState();
}

class _PasswordRecoveryListenerState extends State<PasswordRecoveryListener> {
  StreamSubscription<AuthState>? authSubscription;

  @override
  void initState() {
    super.initState();

    authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
            ResetPasswordPage.routeName,
                (route) => false,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
