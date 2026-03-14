import '../repositories/home_repository.dart';

class DeleteHome {
  final HomeRepository repository;

  DeleteHome(this.repository);

  Future<void> call({required String homeId,}) {
    return repository.deleteHome(homeId: homeId);
  }
}