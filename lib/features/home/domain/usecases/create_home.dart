import '../repositories/home_repository.dart';

class CreateHome {
  final HomeRepository repository;

  CreateHome(this.repository);

  Future<void> call({required String name,}) {
    return repository.createHome(name: name);
  }
}