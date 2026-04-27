import 'package:iot_manager/core/config/supabase_config.dart';

class ShellyTelemetryConfig {
  static const String scriptName = 'tfg_iot_telemetry';
  static const int intervalSeconds = 60;

  static String get ingestUrl =>
      '${SupabaseConfig.supabaseUrl}/functions/v1/shelly_ingest';

  static String get authorizationHeader =>
      'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV1bW9penN0Y2FianJ5cXpxdnZnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE0MTI3OTgsImV4cCI6MjA4Njk4ODc5OH0.CZDDieA8vnJhJ-hIOkBjfbIOGgTFOpDbkslbaUaSmAQ';
}
