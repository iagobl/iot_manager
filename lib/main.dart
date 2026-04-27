import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:iot_manager/app/app.dart';
import 'package:iot_manager/features/app_shell/services/push_notification_service.dart';
import 'package:iot_manager/core/config/firebase_options.dart';
import 'package:iot_manager/core/config/supabase_config.dart';
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

  runApp(const MyApp());
}
