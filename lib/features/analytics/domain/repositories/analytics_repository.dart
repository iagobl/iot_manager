import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';

abstract class AnalyticsRepository {
  Future<List<AnalyticsScopeOption>> getAvailableScopes();

  Future<List<AnalyticsSample>> getSamples(AnalyticsQuery query);

  Future<AnalyticsNormalizationLimits> getDeviceNormalizationLimits(String deviceId);
}