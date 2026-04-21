import 'package:iot_manager/core/constants/auth_strings.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

mixin DeviceDatasourceShared {
  SupabaseClient get client => Supabase.instance.client;

  String requireUserId() {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const ValidationAppException(AuthStrings.notAutenticated);
    }
    return userId;
  }
}
