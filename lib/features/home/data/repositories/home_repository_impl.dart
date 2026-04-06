import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/domain/entities/device_item.dart';
import 'package:iot_manager/features/home/data/datasources/home_remote_datasource.dart';
import 'package:iot_manager/features/home/domain/entities/home_overview.dart';
import 'package:iot_manager/features/home/domain/entities/home_summary.dart';
import 'package:iot_manager/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this.remoteDatasource);
  final HomeRemoteDatasource remoteDatasource;

  @override
  Future<HomeOverview> getOverview() async {
    try {
      final raw = await remoteDatasource.getOverview();

      final profile = raw['profile'] as Map<String, dynamic>?;
      final homesRaw = (raw['homes'] as List).cast<Map<String, dynamic>>();
      final devicesRaw = (raw['devices'] as List).cast<Map<String, dynamic>>();

      return HomeOverview(
        firstName: ((profile?['first_name'] ?? '') as String).trim(),
        homes: homesRaw.map(HomeSummary.fromMap).toList(),
        devices: devicesRaw.map(DeviceItem.fromMap).toList(),
      );
    } catch (e) {
      throw ErrorMapper.mapFailure(e);
    }
  }

  @override
  Future<void> createHome({required String name,}) async {
    try {
      await remoteDatasource.createHome(name: name);
    } catch (e) {
      throw ErrorMapper.mapFailure(e);
    }
  }

  @override
  Future<void> deleteHome({required String homeId,}) async {
    try {
      await remoteDatasource.deleteHome(homeId: homeId);
    } catch (e) {
      throw ErrorMapper.mapFailure(e);
    }
  }

  Future<int> getActiveIncidentsCount(String homeId) async {
    try {
      final result = await remoteDatasource.client
          .from('incidents')
          .select('id')
          .eq('home_id', homeId)
          .eq('resolved', false);

      return result.length;
    } catch (e) {
      throw ErrorMapper.mapFailure(e);
    }
  }
}