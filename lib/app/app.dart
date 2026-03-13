import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme.dart';

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