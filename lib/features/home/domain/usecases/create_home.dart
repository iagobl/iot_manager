import 'package:iot_manager/features/home/domain/repositories/home_repository.dart';

class CreateHome {

  CreateHome(this.repository);
  final HomeRepository repository;

  Future<void> call({required String name,}) {
    return repository.createHome(name: name);
  }
}