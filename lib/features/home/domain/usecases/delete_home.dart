import 'package:iot_manager/features/home/domain/repositories/home_repository.dart';

class DeleteHome {

  DeleteHome(this.repository);
  final HomeRepository repository;

  Future<void> call({required String homeId,}) {
    return repository.deleteHome(homeId: homeId);
  }
}