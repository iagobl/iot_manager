import 'package:iot_manager/features/devices/domain/repositories/device_automations_repository.dart';
import 'package:iot_manager/features/devices/domain/repositories/device_base_repository.dart';
import 'package:iot_manager/features/devices/domain/repositories/device_incidents_repository.dart';
import 'package:iot_manager/features/devices/domain/repositories/device_live_state_repository.dart';
import 'package:iot_manager/features/devices/domain/repositories/device_readings_repository.dart';
import 'package:iot_manager/features/devices/domain/repositories/device_share_repository.dart';

abstract class DevicesRepository
    implements
        DeviceBaseRepository,
        DeviceSharesRepository,
        DeviceIncidentsRepository,
        DeviceAutomationsRepository,
        DeviceReadingsRepository,
        DeviceLiveStateRepository {}
