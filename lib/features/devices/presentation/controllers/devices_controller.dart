import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/app_failure.dart';
import '../../data/datasources/devices_remote_datasource.dart';
import '../../data/repositories/devices_repository_impl.dart';
import '../../domain/entities/device_item.dart';
import '../../domain/usecases/get_user_devices.dart';

class DevicesController extends ChangeNotifier {
  final GetUserDevices getUserDevices;

  DevicesController(this.getUserDevices);

  bool isLoading = false;
  String? errorMessages;
  List<DeviceItem> items = [];

  bool get loading => isLoading;
  String? get errorMessage => errorMessages;
  List<DeviceItem> get devices => items;

  factory DevicesController.create() {
    final client = Supabase.instance.client;
    final datasource = DevicesRemoteDatasource(client);
    final repository = DevicesRepositoryImpl(datasource);
    final usecase = GetUserDevices(repository);
    return DevicesController(usecase);
  }

  Future<void> load() async {
    setLoading(true);
    clearError();

    try {
      items = await getUserDevices();
    } on AppFailure catch (e) {
      setError(e.message);
    } catch (_) {
      setError('No se pudieron cargar los dispositivos.');
    } finally {
      setLoading(false);
    }
  }

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void setError(String message) {
    errorMessages = message;
    notifyListeners();
  }

  void clearError() {
    errorMessages = null;
    notifyListeners();
  }
}
