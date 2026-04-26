import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/core/iot/shelly/shelly_rpc_client.dart';
import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsRemoteDatasource {
  AnalyticsRemoteDatasource({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  String requireUserId() {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const ValidationAppException('Debes iniciar sesión para acceder a las gráficas.');
    }
    return userId;
  }

  Future<List<Map<String, dynamic>>> getAccessibleDevices() async {
    try {
      final userId = requireUserId();

      final ownedResponse = await client.from('devices').select(
        'id, name, home_id, device_type, owner_id, identifier, created_at',
      ).eq('owner_id', userId).order('created_at', ascending: false);

      final owned = (ownedResponse as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();

      final sharesResponse = await client.from('device_shares').select('device_id')
          .eq('shared_with_user_id', userId).eq('status', 'accepted');

      final sharedIds = (sharesResponse as List)
          .map((item) => (item as Map)['device_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty).toSet().toList();

      final shared = <Map<String, dynamic>>[];
      if (sharedIds.isNotEmpty) {
        final sharedResponse = await client.from('devices').select(
          'id, name, home_id, device_type, owner_id, identifier, created_at',
        ).inFilter('id', sharedIds);

        shared.addAll((sharedResponse as List)
            .map((item) => Map<String, dynamic>.from(item as Map)),
        );
      }

      final byId = <String, Map<String, dynamic>>{};
      for (final row in [...owned, ...shared]) {
        final id = (row['id'] ?? '').toString();
        if (id.isNotEmpty) {
          byId[id] = row;
        }
      }

      return byId.values.toList();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<List<Map<String, dynamic>>> getAccessibleHomes() async {
    try {
      final userId = requireUserId();

      final ownedResponse = await client.from('homes')
          .select('id, name, owner_id, created_at')
          .eq('owner_id', userId).order('created_at', ascending: false);

      final owned = (ownedResponse as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();

      final sharedResponse = await client.from('home_shares').select('home_id')
          .eq('shared_with_user_id', userId).eq('status', 'accepted');

      final sharedIds = (sharedResponse as List)
          .map((item) => (item as Map)['home_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty).toSet().toList();

      final shared = <Map<String, dynamic>>[];
      if (sharedIds.isNotEmpty) {
        final homesResponse = await client.from('homes')
            .select('id, name, owner_id, created_at').inFilter('id', sharedIds);

        shared.addAll((homesResponse as List)
              .map((item) => Map<String, dynamic>.from(item as Map)),
        );
      }

      final devices = await getAccessibleDevices();
      final homeIdsFromDevices = devices
          .map((device) => (device['home_id'] ?? '').toString())
          .where((id) => id.isNotEmpty).toSet().toList();

      final existingHomeIds = <String>{
        ...owned.map((e) => (e['id'] ?? '').toString()),
        ...shared.map((e) => (e['id'] ?? '').toString()),
      };

      final missingHomeIds = homeIdsFromDevices
          .where((id) => id.isNotEmpty && !existingHomeIds.contains(id)).toList();

      final fromDevices = <Map<String, dynamic>>[];
      if (missingHomeIds.isNotEmpty) {
        final homesFromDevicesResponse = await client.from('homes')
            .select('id, name, owner_id, created_at')
            .inFilter('id', missingHomeIds);

        fromDevices.addAll((homesFromDevicesResponse as List)
              .map((item) => Map<String, dynamic>.from(item as Map)),
        );
      }

      final byId = <String, Map<String, dynamic>>{};
      for (final row in [...owned, ...shared, ...fromDevices]) {
        final id = (row['id'] ?? '').toString();
        if (id.isNotEmpty) {
          byId[id] = row;
        }
      }

      final homes = byId.values.toList()..sort((a, b) {
          final aCreated = DateTime.tryParse((a['created_at'] ?? '').toString());
          final bCreated = DateTime.tryParse((b['created_at'] ?? '').toString());

          if (aCreated == null && bCreated == null) return 0;
          if (aCreated == null) return 1;
          if (bCreated == null) return -1;

          return bCreated.compareTo(aCreated);
        });

      return homes;
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<List<Map<String, dynamic>>> fetchReadings({
    required List<String> deviceIds,
    required DateTime from,
    required DateTime to,
    int limit = 30000,
  }) async {
    try {
      if (deviceIds.isEmpty) return <Map<String, dynamic>>[];

      final candidateTimestampColumns = <String>[
        'ts',
        'created_at',
        'recorded_at',
        'timestamp',
        'measured_at',
        'inserted_at',
      ];

      for (final timestampColumn in candidateTimestampColumns) {
        try {
          return await _fetchReadingsWithPagination(
            deviceIds: deviceIds,
            from: from,
            to: to,
            timestampColumn: timestampColumn,
            limit: limit,
          );
        } catch (_) {
        }
      }

      final allRows = await _fetchAllReadingsWithPagination(
        deviceIds: deviceIds,
        limit: limit,
      );

      bool inRange(DateTime timestamp) {
        return !timestamp.isBefore(from) && !timestamp.isAfter(to);
      }

      allRows.removeWhere((row) {
        final timestamp = extractTimestamp(row);
        return timestamp == null || !inRange(timestamp);
      });

      allRows.sort((a, b) {
        final aTs = extractTimestamp(a) ?? from;
        final bTs = extractTimestamp(b) ?? from;
        return aTs.compareTo(bTs);
      });

      if (allRows.length > limit) {
        return allRows.sublist(0, limit);
      }

      return allRows;
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReadingsWithPagination({
    required List<String> deviceIds,
    required DateTime from,
    required DateTime to,
    required String timestampColumn,
    int limit = 30000,
  }) async {
    const pageSize = 1000; // Límite de Supabase
    final allRows = <Map<String, dynamic>>[];
    int offset = 0;
    int consecutiveEmptyPages = 0;
    const maxConsecutiveEmptyPages = 3;

    while (allRows.length < limit && consecutiveEmptyPages < maxConsecutiveEmptyPages) {
      final response = await client
          .from('readings')
          .select('*')
          .inFilter('device_id', deviceIds)
          .gte(timestampColumn, from.toUtc().toIso8601String())
          .lte(timestampColumn, to.toUtc().toIso8601String())
          .order(timestampColumn, ascending: true)
          .range(offset, offset + pageSize - 1);

      final rows = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (rows.isEmpty) {
        consecutiveEmptyPages++;
        break;
      } else {
        consecutiveEmptyPages = 0;
      }

      allRows.addAll(rows);
      offset += pageSize;
    }

    return allRows;
  }

  Future<List<Map<String, dynamic>>> _fetchAllReadingsWithPagination({
    required List<String> deviceIds,
    int limit = 30000,
  }) async {
    const pageSize = 1000; // Límite de Supabase
    final allRows = <Map<String, dynamic>>[];
    int offset = 0;
    int consecutiveEmptyPages = 0;
    const maxConsecutiveEmptyPages = 3;

    while (allRows.length < limit && consecutiveEmptyPages < maxConsecutiveEmptyPages) {
      final response = await client
          .from('readings')
          .select('*')
          .inFilter('device_id', deviceIds)
          .range(offset, offset + pageSize - 1);

      final rows = (response as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (rows.isEmpty) {
        consecutiveEmptyPages++;
        break;
      } else {
        consecutiveEmptyPages = 0;
      }

      allRows.addAll(rows);
      offset += pageSize;
    }

    return allRows;
  }

  DateTime? extractTimestamp(Map<String, dynamic> row) {
    const candidates = <String>[
      'ts',
      'created_at',
      'recorded_at',
      'timestamp',
      'measured_at',
      'inserted_at',
    ];

    for (final key in candidates) {
      final raw = row[key];
      if (raw == null) continue;
      final parsed = DateTime.tryParse(raw.toString());
      if (parsed != null) return parsed.toLocal();
    }

    final meta = row['meta'];
    if (meta is Map) {
      for (final key in candidates) {
        final raw = meta[key];
        if (raw == null) continue;
        final parsed = DateTime.tryParse(raw.toString());
        if (parsed != null) return parsed.toLocal();
      }
    }

    return null;
  }

  Future<AnalyticsNormalizationLimits> getDeviceNormalizationLimits(
      String deviceId,
      ) async {
    try {
      final response = await client.from('devices').select('identifier')
          .eq('id', deviceId).maybeSingle();

      if (response == null) {
        return AnalyticsNormalizationLimits.empty;
      }

      final row = Map<String, dynamic>.from(response as Map);
      final host = (row['identifier'] ?? '').toString().trim();

      if (host.isEmpty) {
        return AnalyticsNormalizationLimits.empty;
      }

      final rpc = ShellyRpcClient(host: host);
      final config = await rpc.call('Switch.GetConfig', params: {'id': 0});

      double toDouble(Object? value) {
        if (value is num) return value.toDouble();
        return double.tryParse((value ?? '').toString().replaceAll(',', '.')) ?? 0;
      }

      return AnalyticsNormalizationLimits(
        powerW: toDouble(config['power_limit']),
        voltageV: toDouble(config['voltage_limit']),
        currentA: toDouble(config['current_limit']),
        usesDeviceLimits: true,
      );
    } catch (_) {
      return AnalyticsNormalizationLimits.empty;
    }
  }

  Future<Map<String, double>> getCurrentPowerByDeviceIds(
      List<String> deviceIds,
      ) async {
    try {
      if (deviceIds.isEmpty) return <String, double>{};

      final response = await client.from('devices').select('id, identifier').inFilter('id', deviceIds);

      final rows = (response as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();

      final result = <String, double>{};

      for (final row in rows) {
        final id = (row['id'] ?? '').toString();
        final host = (row['identifier'] ?? '').toString().trim();

        if (id.isEmpty || host.isEmpty) {
          continue;
        }

        try {
          final rpc = ShellyRpcClient(host: host);
          final status = await rpc.call('Switch.GetStatus', params: {'id': 0});

          double toDouble(Object? value) {
            if (value is num) return value.toDouble();
            return double.tryParse((value ?? '').toString().replaceAll(',', '.')) ?? 0;
          }

          result[id] = toDouble(status['apower']);
        } catch (_) {
          result[id] = 0.0;
        }
      }

      return result;
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }
}
