import 'package:flutter/material.dart';
import 'package:iot_manager/app/theme.dart';
import '../features/app_shell/presentation/app_shell.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Manager',
      debugShowCheckedModeBanner: false,
      home: const AppShell(),
      theme: AppTheme.basic,
    );
  }
}