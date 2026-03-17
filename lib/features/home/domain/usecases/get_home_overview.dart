import 'package:iot_manager/features/home/domain/entities/home_overview.dart';
import 'package:iot_manager/features/home/domain/repositories/home_repository.dart';

class GetHomeOverview {

  GetHomeOverview(this.repository);
  final HomeRepository repository;

  Future<HomeOverview> call() {
    return repository.getOverview();
  }
}
