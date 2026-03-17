import 'package:flutter/material.dart';

import 'package:iot_manager/app/routes.dart';
import 'package:iot_manager/app/theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoTServices',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.basic,
      initialRoute: Routes.authGate,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}