import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/analytics/data/datasources/analytics_remote_datasource.dart';
import 'package:iot_manager/features/analytics/data/repositories/analytics_repository_impl.dart';
import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';

class AnalyticsController extends ChangeNotifier {
  AnalyticsController({
    AnalyticsRepositoryImpl? repository,
  }) : repository = repository ?? AnalyticsRepositoryImpl(AnalyticsRemoteDatasource());

  final AnalyticsRepositoryImpl repository;

  AnalyticsState _state = AnalyticsState.initial();
  AnalyticsState get state => _state;

  List<AnalyticsSample> samples = const [];
  Map<String, double> livePowerByDevice = const {};
  final List<AnalyticsPoint> livePowerHistory = <AnalyticsPoint>[];
  Timer? liveRefreshTimer;
  bool initialized = false;

  bool get isAggregateScope =>
      _state.selectedScope != null && _state.selectedScope!.type == AnalyticsScopeType.home;

  Future<void> initialize() async {
    if (initialized) return;
    initialized = true;

    await loadInitialData();
    startLiveRefresh();
  }

  @override
  void dispose() {
    liveRefreshTimer?.cancel();
    super.dispose();
  }

  void startLiveRefresh() {
    liveRefreshTimer?.cancel();
    liveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await refreshLivePower();
    });
  }

  Future<void> loadInitialData() async {
    emit(_state.copyWith(loading: true, clearError: true));

    try {
      final scopes = await repository.getAvailableScopes();

      AnalyticsScopeGroup selectedGroup = AnalyticsScopeGroup.global;
      AnalyticsScopeOption? selectedScope;

      final globalScopes = scopes.where((scope) => scope.type == AnalyticsScopeType.home).toList();
      final deviceScopes = scopes.where((scope) => scope.type == AnalyticsScopeType.device).toList();

      if (globalScopes.isNotEmpty) {
        selectedScope = globalScopes.first;
        selectedGroup = AnalyticsScopeGroup.global;
      } else if (deviceScopes.isNotEmpty) {
        selectedScope = deviceScopes.first;
        selectedGroup = AnalyticsScopeGroup.device;
      }

      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = now;

      emit(
        _state.copyWith(
          loading: false,
          scopes: scopes,
          selectedScope: selectedScope,
          selectedGroup: selectedGroup,
          rangePreset: AnalyticsRangePreset.today,
          from: from,
          to: to,
        ),
      );

      await refresh();
      await refreshLivePower();
    } catch (error) {
      emit(
        _state.copyWith(
          loading: false,
          errorMessage: ErrorMapper.mapException(error).message,
        ),
      );
    }
  }

  Future<void> refresh({bool silent = false}) async {
    final scope = _state.selectedScope;
    if (scope == null) {
      if (!silent) {
        emit(_state.copyWith(loading: false));
      }
      return;
    }

    if (!silent) {
      emit(_state.copyWith(loading: true, clearError: true));
    }

    try {
      final query = AnalyticsQuery(
        scope: scope,
        rangePreset: _state.rangePreset,
        from: _state.from,
        to: _state.to,
      );

      final samples = await repository.getSamples(query);
      this.samples = samples;

      final series = AnalyticsSeries.fromSamples(samples);
      final summary = _buildSummary(samples);

      AnalyticsNormalizationLimits normalizationLimits = AnalyticsNormalizationLimits.empty;

      if (scope.type == AnalyticsScopeType.device &&
          scope.deviceId != null &&
          scope.deviceId!.isNotEmpty) {
        normalizationLimits = await repository.getDeviceNormalizationLimits(scope.deviceId!);
      }

      emit(
        _state.copyWith(
          loading: false,
          series: series,
          summary: summary,
          normalizationLimits: normalizationLimits,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        _state.copyWith(
          loading: false,
          errorMessage: ErrorMapper.mapException(error).message,
        ),
      );
    }
  }

  Future<void> refreshLivePower() async {
    final scope = _state.selectedScope;
    if (scope == null) return;

    try {
      livePowerByDevice = await repository.getCurrentPowerByScope(scope);

      final totalPower = livePowerByDevice.values.fold<double>(
        0.0, (sum, value) => sum + value,
      );

      registerLivePowerPoint(totalPower);
      notifyListeners();
    } catch (_) {}
  }

  void registerLivePowerPoint(double totalPower) {
    final now = DateTime.now();

    livePowerHistory.add(
      AnalyticsPoint(
        timestamp: now,
        powerW: totalPower,
        voltageV: 0,
        currentA: 0,
        energyWh: 0,
      ),
    );

    final cutoff = now.subtract(const Duration(hours: 4));
    livePowerHistory.removeWhere((point) => point.timestamp.isBefore(cutoff));

    const maxPoints = 240;
    if (livePowerHistory.length > maxPoints) {
      livePowerHistory.removeRange(0, livePowerHistory.length - maxPoints);
    }
  }

  void selectGroup(AnalyticsScopeGroup group) {
    if (_state.selectedGroup == group) return;

    final options = scopesForGroup(group);
    final newSelected = options.isNotEmpty ? options.first : null;

    resetLiveHistory();

    emit(
      _state.copyWith(
        selectedGroup: group,
        selectedScope: newSelected,
      ),
    );

    unawaited(refresh());
    unawaited(refreshLivePower());
  }

  void selectScope(String scopeId) {
    final option = _state.scopes.firstWhere((scope) => scope.id == scopeId,
      orElse: () => _state.selectedScope ?? _state.scopes.first,
    );

    if (_state.selectedScope?.id == option.id) return;

    final targetGroup = option.type == AnalyticsScopeType.device
        ? AnalyticsScopeGroup.device : AnalyticsScopeGroup.global;

    resetLiveHistory();

    emit(
      _state.copyWith(
        selectedGroup: targetGroup,
        selectedScope: option,
      ),
    );

    unawaited(refresh());
    unawaited(refreshLivePower());
  }

  void selectRangePreset(AnalyticsRangePreset preset) {
    final now = DateTime.now();
    final from = resolveRangeStart(preset, now);
    final to = resolveRangeEnd(preset, now);

    resetLiveHistory();

    emit(
      _state.copyWith(
        rangePreset: preset,
        from: from,
        to: to,
      ),
    );

    unawaited(refresh());
  }

  void setCustomRange(DateTimeRange range) {
    final from = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
      0, 0, 0,
    );
    final to = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23, 59, 59, 999,
    );

    resetLiveHistory();

    emit(
      _state.copyWith(
        rangePreset: AnalyticsRangePreset.custom,
        from: from,
        to: to,
      ),
    );

    unawaited(refresh());
  }

  List<AnalyticsScopeOption> scopesForGroup(AnalyticsScopeGroup group) {
    switch (group) {
      case AnalyticsScopeGroup.global:
        return _state.scopes.where((scope) => scope.type == AnalyticsScopeType.home).toList();
      case AnalyticsScopeGroup.device:
        return _state.scopes.where((scope) => scope.type == AnalyticsScopeType.device).toList();
    }
  }

  DateTime resolveRangeStart(AnalyticsRangePreset preset, DateTime now) {
    switch (preset) {
      case AnalyticsRangePreset.today:
        return DateTime(now.year, now.month, now.day);
      case AnalyticsRangePreset.last7Days:
        final weekday = now.weekday;
        return DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday - 1));
      case AnalyticsRangePreset.last30Days:
        return DateTime(now.year, now.month, 1);
      case AnalyticsRangePreset.custom:
        return _state.from;
    }
  }

  DateTime resolveRangeEnd(AnalyticsRangePreset preset, DateTime now) {
    switch (preset) {
      case AnalyticsRangePreset.today:
      case AnalyticsRangePreset.last7Days:
      case AnalyticsRangePreset.last30Days:
        return now;
      case AnalyticsRangePreset.custom:
        return _state.to;
    }
  }

  String rangeLabel() {
    switch (_state.rangePreset) {
      case AnalyticsRangePreset.today:
        return 'Hoy';
      case AnalyticsRangePreset.last7Days:
        return 'Semana actual';
      case AnalyticsRangePreset.last30Days:
        return 'Este mes';
      case AnalyticsRangePreset.custom:
        return formatRange(_state.from, _state.to);
    }
  }

  void resetLiveHistory() {
    livePowerHistory.clear();
  }

  AnalyticsSeries get currentMomentChartSeries {
    if (livePowerHistory.isEmpty) {
      return const AnalyticsSeries(
        points: [],
        totalEnergyWh: 0,
        averagePowerW: 0,
        averageVoltageV: 0,
        averageCurrentA: 0,
        maxPowerW: 0,
        maxVoltageV: 0,
        maxCurrentA: 0,
        minPowerW: 0,
        minVoltageV: 0,
        minCurrentA: 0,
      );
    }

    final points = List<AnalyticsPoint>.from(livePowerHistory)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final powerValues = points.map((point) => point.powerW).toList();
    final avgPower = powerValues.fold<double>(0.0, (sum, value) => sum + value) / powerValues.length;

    return AnalyticsSeries(
      points: points,
      totalEnergyWh: 0,
      averagePowerW: avgPower,
      averageVoltageV: 0,
      averageCurrentA: 0,
      maxPowerW: powerValues.reduce(math.max),
      maxVoltageV: 0,
      maxCurrentA: 0,
      minPowerW: powerValues.reduce(math.min),
      minVoltageV: 0,
      minCurrentA: 0,
    );
  }

  String formatRange(DateTime from, DateTime to) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final fromText = '${twoDigits(from.day)}/${twoDigits(from.month)}/${from.year}';
    final toText = '${twoDigits(to.day)}/${twoDigits(to.month)}/${to.year}';
    return '$fromText - $toText';
  }

  double get currentPowerW {
    if (livePowerByDevice.isNotEmpty) {
      return livePowerByDevice.values.fold<double>(
        0.0, (sum, value) => sum + value,
      );
    }

    if (samples.isEmpty) return 0.0;

    if (!isAggregateScope) {
      final sorted = [...samples]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return sorted.last.powerW;
    }

    final latestByDevice = <String, AnalyticsSample>{};
    for (final sample in samples) {
      final previous = latestByDevice[sample.deviceId];
      if (previous == null || sample.timestamp.isAfter(previous.timestamp)) {
        latestByDevice[sample.deviceId] = sample;
      }
    }

    return latestByDevice.values.fold<double>(
      0.0, (sum, sample) => sum + sample.powerW,
    );
  }

  double get displayAveragePowerW {
    if (samples.isEmpty) return 0.0;

    if (!isAggregateScope) {
      return _state.series.averagePowerW;
    }

    final grouped = <int, double>{};

    for (final sample in samples) {
      final key = DateTime(
        sample.timestamp.year,
        sample.timestamp.month,
        sample.timestamp.day,
        sample.timestamp.hour,
        sample.timestamp.minute,
      ).millisecondsSinceEpoch;

      grouped.update(key, (value) => value + sample.powerW, ifAbsent: () => sample.powerW);
    }

    if (grouped.isEmpty) return 0.0;

    final values = grouped.values.toList();
    final total = values.fold<double>(0.0, (sum, value) => sum + value);
    return total / values.length;
  }

  double get displayPeakPowerW {
    if (samples.isEmpty) return 0.0;

    return samples.fold<double>(
      0.0, (maxValue, sample) => math.max(maxValue, sample.powerW),
    );
  }

  double get rangeConsumptionWh => calculateRangeConsumptionWh(samples);

  bool get isCurrentlyOn => currentPowerW > 0.5;

  AnalyticsSummary _buildSummary(List<AnalyticsSample> samples) {
    if (samples.isEmpty) {
      return const AnalyticsSummary(
        totalEnergyWh: 0,
        averagePowerW: 0,
        averageVoltageV: 0,
        averageCurrentA: 0,
        peakPowerW: 0,
        peakVoltageV: 0,
        peakCurrentA: 0,
        activeDevices: 0,
        samples: 0,
      );
    }

    final totalEnergyWh = calculateRangeConsumptionWh(samples);

    final averagePowerW = samples.fold<double>(0.0, (sum, item) => sum + item.powerW) / samples.length;
    final averageVoltageV = samples.fold<double>(0.0, (sum, item) => sum + item.voltageV) / samples.length;
    final averageCurrentA = samples.fold<double>(0.0, (sum, item) => sum + item.currentA) / samples.length;

    final peakPowerW = samples.fold<double>(0.0, (maxValue, item) => math.max(maxValue, item.powerW));
    final peakVoltageV = samples.fold<double>(0.0, (maxValue, item) => math.max(maxValue, item.voltageV));
    final peakCurrentA = samples.fold<double>(0.0, (maxValue, item) => math.max(maxValue, item.currentA));

    final activeDevices = samples.where((sample) => sample.powerW > 0.0)
        .map((sample) => sample.deviceId).toSet().length;

    return AnalyticsSummary(
      totalEnergyWh: totalEnergyWh,
      averagePowerW: averagePowerW,
      averageVoltageV: averageVoltageV,
      averageCurrentA: averageCurrentA,
      peakPowerW: peakPowerW,
      peakVoltageV: peakVoltageV,
      peakCurrentA: peakCurrentA,
      activeDevices: activeDevices,
      samples: samples.length,
    );
  }

  double calculateRangeConsumptionWh(List<AnalyticsSample> input) {
    if (input.isEmpty) return 0.0;

    final byDevice = <String, List<AnalyticsSample>>{};
    for (final sample in input) {
      byDevice.putIfAbsent(sample.deviceId, () => <AnalyticsSample>[]).add(sample);
    }

    double total = 0.0;

    for (final entries in byDevice.values) {
      entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (entries.length < 2) continue;

      for (var i = 1; i < entries.length; i++) {
        final previous = entries[i - 1].energyWh;
        final current = entries[i].energyWh;
        final delta = current - previous;

        if (delta.isFinite && delta > 0) {
          total += delta;
        }
      }
    }

    return total;
  }

  Future<void> exportPdf(BuildContext context) async {
    emit(_state.copyWith(exporting: true, clearError: true));

    await Future<void>.delayed(const Duration(milliseconds: 500));

    emit(_state.copyWith(exporting: false));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La exportación PDF se deja para el siguiente ajuste.'),
        ),
      );
    }
  }

  void clearError() {
    if (_state.errorMessage == null) return;
    emit(_state.copyWith(clearError: true));
  }

  void emit(AnalyticsState newState) {
    _state = newState;
    notifyListeners();
  }
}