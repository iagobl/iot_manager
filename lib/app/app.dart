import 'package:flutter/material.dart';

import 'package:iot_manager/app/app_navigator.dart';
import 'package:iot_manager/app/routes.dart';
import 'package:iot_manager/app/theme.dart';
import 'package:iot_manager/features/profile/presentation/pages/reset_password_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'IoTServices',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.basic,
      initialRoute: Routes.authGate,
      routes: {ResetPasswordPage.routeName: (_) => const ResetPasswordPage()},
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
