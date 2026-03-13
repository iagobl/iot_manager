import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Manager',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: Center(
          child: Text('App initialized'),
        ),
      ),
    );
  }
}