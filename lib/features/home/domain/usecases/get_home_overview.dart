import '../entities/home_overview.dart';
import '../repositories/home_repository.dart';

class GetHomeOverview {
  final HomeRepository repository;

  GetHomeOverview(this.repository);

  Future<HomeOverview> call() {
    return repository.getOverview();
  }
}
