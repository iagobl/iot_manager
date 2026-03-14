import '../../../../core/error/error_mapper.dart';
import '../../../devices/domain/entities/device_item.dart';
import '../../domain/entities/home_overview.dart';
import '../../domain/entities/home_summary.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_remote_datasource.dart';

class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDatasource remoteDatasource;

  HomeRepositoryImpl(this.remoteDatasource);

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
}