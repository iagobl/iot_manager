import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/analytics/data/datasources/analytics_remote_datasource.dart';
import 'package:iot_manager/features/analytics/data/repositories/analytics_repository_impl.dart';
import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';

class AnalyticsController extends ChangeNotifier {
  AnalyticsController({
    AnalyticsRepositoryImpl? repository,
  }) : _repository = repository ?? AnalyticsRepositoryImpl(AnalyticsRemoteDatasource());

  final AnalyticsRepositoryImpl _repository;

  AnalyticsState _state = AnalyticsState.initial();
  AnalyticsState get state => _state;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _loadInitialData();
  }

  Future<void> retry() async {
    await _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    _emit(_state.copyWith(loading: true, clearError: true));

    try {
      final scopes = await _repository.getAvailableScopes();

      AnalyticsScopeGroup selectedGroup = AnalyticsScopeGroup.global;

      AnalyticsScopeOption? selectedScope;
      final globalScopes = scopes
          .where((scope) => scope.type == AnalyticsScopeType.allDevices || scope.type == AnalyticsScopeType.home)
          .toList();
      final deviceScopes =
      scopes.where((scope) => scope.type == AnalyticsScopeType.device).toList();

      if (globalScopes.isNotEmpty) {
        selectedScope = globalScopes.first;
        selectedGroup = AnalyticsScopeGroup.global;
      } else if (deviceScopes.isNotEmpty) {
        selectedScope = deviceScopes.first;
        selectedGroup = AnalyticsScopeGroup.device;
      }

      if (selectedScope == null) {
        _emit(
          _state.copyWith(
            loading: false,
            scopes: scopes,
            selectedScope: null,
            selectedGroup: selectedGroup,
            series: const AnalyticsSeries(
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
            ),
            summary: const AnalyticsSummary(
              totalEnergyWh: 0,
              averagePowerW: 0,
              averageVoltageV: 0,
              averageCurrentA: 0,
              peakPowerW: 0,
              peakVoltageV: 0,
              peakCurrentA: 0,
              activeDevices: 0,
              samples: 0,
            ),
            normalizationLimits: AnalyticsNormalizationLimits.empty,
          ),
        );
        return;
      }

      final now = DateTime.now();
      final from = _resolveRangeStart(AnalyticsRangePreset.today, now);
      final to = _resolveRangeEnd(AnalyticsRangePreset.today, now);

      _emit(
        _state.copyWith(
          scopes: scopes,
          selectedScope: selectedScope,
          selectedGroup: selectedGroup,
          rangePreset: AnalyticsRangePreset.today,
          from: from,
          to: to,
        ),
      );

      await refresh();
    } catch (error) {
      _emit(
        _state.copyWith(
          loading: false,
          errorMessage: ErrorMapper.mapException(error).message,
        ),
      );
    }
  }

  Future<void> refresh() async {
    final scope = _state.selectedScope;
    if (scope == null) {
      _emit(_state.copyWith(loading: false));
      return;
    }

    _emit(_state.copyWith(loading: true, clearError: true));

    try {
      final query = AnalyticsQuery(
        scope: scope,
        rangePreset: _state.rangePreset,
        from: _state.from,
        to: _state.to,
      );

      final samples = await _repository.getSamples(query);
      final series = AnalyticsSeries.fromSamples(samples);
      final summary = _repository.buildSummary(samples);

      AnalyticsNormalizationLimits normalizationLimits =
          AnalyticsNormalizationLimits.empty;

      if (scope.type == AnalyticsScopeType.device &&
          scope.deviceId != null &&
          scope.deviceId!.isNotEmpty) {
        normalizationLimits = await _repository.getDeviceNormalizationLimits(
          scope.deviceId!,
        );
      }

      _emit(
        _state.copyWith(
          loading: false,
          series: series,
          summary: summary,
          normalizationLimits: normalizationLimits,
        ),
      );
    } catch (error) {
      _emit(
        _state.copyWith(
          loading: false,
          errorMessage: ErrorMapper.mapException(error).message,
        ),
      );
    }
  }

  void selectGroup(AnalyticsScopeGroup group) {
    if (_state.selectedGroup == group) return;

    final options = scopesForGroup(group);
    final newSelected = options.isNotEmpty ? options.first : null;

    _emit(
      _state.copyWith(
        selectedGroup: group,
        selectedScope: newSelected,
      ),
    );

    unawaited(refresh());
  }

  void selectScope(String scopeId) {
    final option = _state.scopes.firstWhere(
          (scope) => scope.id == scopeId,
      orElse: () => _state.selectedScope ?? _state.scopes.first,
    );

    if (_state.selectedScope?.id == option.id) return;

    final targetGroup = option.type == AnalyticsScopeType.device
        ? AnalyticsScopeGroup.device
        : AnalyticsScopeGroup.global;

    _emit(
      _state.copyWith(
        selectedGroup: targetGroup,
        selectedScope: option,
      ),
    );

    unawaited(refresh());
  }

  void selectRangePreset(AnalyticsRangePreset preset) {
    final now = DateTime.now();
    final from = _resolveRangeStart(preset, now);
    final to = _resolveRangeEnd(preset, now);

    _emit(
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
      0,
      0,
      0,
    );
    final to = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );

    _emit(
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
        return _state.scopes
            .where(
              (scope) =>
          scope.type == AnalyticsScopeType.allDevices ||
              scope.type == AnalyticsScopeType.home,
        )
            .toList();
      case AnalyticsScopeGroup.device:
        return _state.scopes
            .where((scope) => scope.type == AnalyticsScopeType.device)
            .toList();
    }
  }

  DateTime _resolveRangeStart(AnalyticsRangePreset preset, DateTime now) {
    switch (preset) {
      case AnalyticsRangePreset.today:
        return DateTime(now.year, now.month, now.day);
      case AnalyticsRangePreset.last7Days:
        final start = now.subtract(const Duration(days: 6));
        return DateTime(start.year, start.month, start.day);
      case AnalyticsRangePreset.last30Days:
        final start = now.subtract(const Duration(days: 29));
        return DateTime(start.year, start.month, start.day);
      case AnalyticsRangePreset.custom:
        return _state.from;
    }
  }

  DateTime _resolveRangeEnd(AnalyticsRangePreset preset, DateTime now) {
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
        return _formatRange(_state.from, _state.to);
    }
  }

  String scopeLabel() {
    final scope = _state.selectedScope;
    if (scope == null) return 'Sin ámbito';
    return scope.label;
  }

  String _formatRange(DateTime from, DateTime to) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final fromText =
        '${twoDigits(from.day)}/${twoDigits(from.month)}/${from.year}';
    final toText = '${twoDigits(to.day)}/${twoDigits(to.month)}/${to.year}';
    return '$fromText - $toText';
  }

  Future<void> exportPdf(BuildContext context) async {
    _emit(_state.copyWith(exporting: true, clearError: true));

    try {
      await Future<void>.delayed(const Duration(milliseconds: 800));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La exportación en PDF estará disponible próximamente.'),
          ),
        );
      }

      _emit(_state.copyWith(exporting: false));
    } catch (error) {
      _emit(
        _state.copyWith(
          exporting: false,
          errorMessage: ErrorMapper.mapException(error).message,
        ),
      );
    }
  }

  void clearError() {
    if (_state.errorMessage == null) return;
    _emit(_state.copyWith(clearError: true));
  }

  void _emit(AnalyticsState newState) {
    _state = newState;
    notifyListeners();
  }
}