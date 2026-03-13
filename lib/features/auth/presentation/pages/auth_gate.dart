import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/routes.dart';

final supabase = Supabase.instance.client;

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (session == null) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              Routes.login, (_) => false,
            );
            return;
          }

          Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.home, (_) => false,
          );
        });

        return const SizedBox.shrink();
      },
    );
  }
}