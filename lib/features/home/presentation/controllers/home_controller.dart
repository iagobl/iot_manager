import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/home_strings.dart';
import '../../../../core/error/app_failure.dart';
import '../../../devices/domain/entities/device_item.dart';
import '../../data/datasources/home_remote_datasource.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../domain/entities/home_overview.dart';
import '../../domain/entities/home_summary.dart';
import '../../domain/usecases/create_home.dart';
import '../../domain/usecases/delete_home.dart';
import '../../domain/usecases/get_home_overview.dart';

class HomeController extends ChangeNotifier {
  final GetHomeOverview getHomeOverview;
  final CreateHome createHomeUseCase;
  final DeleteHome deleteHomeUseCase;

  HomeController(this.getHomeOverview, this.createHomeUseCase, this.deleteHomeUseCase,);

  bool isLoading = false;
  bool isCreatingHome = false;
  String? deletingHomeId;
  String? errorMessages;
  HomeOverview? overview;

  bool get loading => isLoading;
  bool get creatingHome => isCreatingHome;
  bool get deletingHome => deletingHomeId != null;
  String? get deletingId => deletingHomeId;
  String? get errorMessage => errorMessages;
  String get firstName => overview?.firstName ?? '';
  List<HomeSummary> get homes => overview?.homes ?? const [];
  List<DeviceItem> get devices => overview?.devices ?? const [];
  int get totalHomes => overview?.totalHomes ?? 0;
  int get totalDevices => overview?.totalDevices ?? 0;
  int get activeDevices => overview?.activeDevices ?? 0;
  double get totalTodayWh => overview?.totalTodayWh ?? 0;

  factory HomeController.create() {
    final client = Supabase.instance.client;
    final datasource = HomeRemoteDatasource(client);
    final repository = HomeRepositoryImpl(datasource);

    final overviewUseCase = GetHomeOverview(repository);
    final createUseCase = CreateHome(repository);
    final deleteUseCase = DeleteHome(repository);

    return HomeController(
      overviewUseCase,
      createUseCase,
      deleteUseCase,
    );
  }

  Future<void> load() async {
    setLoading(true);
    clearError();

    try {
      overview = await getHomeOverview();
    } on AppFailure catch (e) {
      setError(e.message);
    } catch (_) {
      setError(HomeStrings.errorLoadInformationHome);
    } finally {
      setLoading(false);
    }
  }

  Future<bool> createHome(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      setError(HomeStrings.errorNotNameHome);
      return false;
    }

    isCreatingHome = true;
    clearError();
    notifyListeners();

    try {
      await createHomeUseCase(name: trimmed);
      await load();
      return true;
    } on AppFailure catch (e) {
      setError(e.message);
      return false;
    } catch (_) {
      setError(HomeStrings.notConfirmationCreateHome);
      return false;
    } finally {
      isCreatingHome = false;
      notifyListeners();
    }
  }

  Future<bool> deleteHome(String homeId) async {
    if (homeId.trim().isEmpty) {
      setError(HomeStrings.errorIdentifyHome);
      return false;
    }

    deletingHomeId = homeId;
    clearError();
    notifyListeners();

    try {
      await deleteHomeUseCase(homeId: homeId);
      await load();
      return true;
    } on AppFailure catch (e) {
      setError(e.message);
      return false;
    } catch (_) {
      setError(HomeStrings.notConfirmationDeleteHome);
      return false;
    } finally {
      deletingHomeId = null;
      notifyListeners();
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
  }
}