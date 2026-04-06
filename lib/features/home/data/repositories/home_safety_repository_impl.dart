import 'package:iot_manager/features/home/data/datasources/home_safety_remote_datasource.dart';

class HomeSafetyRepositoryImpl {
  final HomeSafetyRemoteDataSource remote = HomeSafetyRemoteDataSource();

  Future<Map<String, dynamic>?> getSafetySettings(String homeId) {
    return remote.getSafetySettings(homeId);
  }

  Future<void> upsertSafetySettings({required String homeId, double? maxTotalConsumptionWh}) async {
    await remote.upsertSafetySettings(
      homeId: homeId,
      maxTotalConsumptionWh: maxTotalConsumptionWh,
    );
  }
}