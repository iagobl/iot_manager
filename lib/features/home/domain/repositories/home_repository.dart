import 'package:iot_manager/features/home/domain/entities/home_overview.dart';

abstract class HomeRepository {
  Future<HomeOverview> getOverview();

  Future<void> createHome({required String name,});

  Future<void> deleteHome({required String homeId,});
}
