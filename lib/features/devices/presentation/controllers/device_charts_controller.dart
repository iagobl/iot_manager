import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/repositories/devices_repository_impl.dart';
import 'package:iot_manager/features/devices/domain/usecases/fetch_readings_range.dart';

enum ChartRange { today, week, month }
enum ChartMetric { consumption, power, voltage }

class DeviceChartsController extends ChangeNotifier {
  DeviceChartsController({
    required this.deviceId,
    required DevicesRemoteDatasource remoteDatasource,
    this.maxSafetyValue,
  }) : fetchReadingsRange = FetchReadingsRange(
    DevicesRepositoryImpl(remoteDatasource),
  );

  static const Duration liveWindowDuration = Duration(minutes: 20);

  final String deviceId;
  final FetchReadingsRange fetchReadingsRange;
  final double? maxSafetyValue;

  ChartRange range = ChartRange.today;
  ChartMetric metric = ChartMetric.voltage;

  bool loading = false;
  bool refreshing = false;
  String? errorMessage;

  List<Map<String, dynamic>> _rows = const [];
  Timer? refreshTimer;
  String lastSignature = '';

  List<Map<String, dynamic>> get rows => _rows;

  DateTime get now => DateTime.now();

  DateTime get from {
    final n = DateTime.now();

    switch (range) {
      case ChartRange.today:
        return n.subtract(liveWindowDuration);
      case ChartRange.week:
        return n.subtract(const Duration(days: 7));
      case ChartRange.month:
        return n.subtract(const Duration(days: 30));
    }
  }

  PreparedChartData get chartData => buildChartData(
    rows: _rows,
    from: from,
    now: now,
    range: range,
    metric: metric,
    maxSafetyValue: maxSafetyValue,
  );

  Future<void> init() async {
    await load(initial: true);
    startSilentRefresh();
  }

  Future<void> load({bool initial = false}) async {
    if (initial) {
      loading = true;
      errorMessage = null;
      notifyListeners();
    } else {
      refreshing = true;
      notifyListeners();
    }

    try {
      final result = await fetchReadingsRange(
        deviceId: deviceId,
        from: from,
        to: DateTime.now(),
        limit: 10000,
      );

      result.sort((a, b) {
        final aTs = (a['ts'] ?? '').toString();
        final bTs = (b['ts'] ?? '').toString();
        return aTs.compareTo(bTs);
      });

      final newSignature = _buildRowsSignature(result);

      if (initial || newSignature != lastSignature) {
        _rows = result;
        lastSignature = newSignature;
      }

      errorMessage = null;
    } catch (error) {
      errorMessage = ErrorMapper.mapFailure(error).message;
      debugPrint('[DeviceChartsController] load -> $error');
    } finally {
      loading = false;
      refreshing = false;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    await load(initial: true);
  }

  void setRange(ChartRange newRange) {
    if (range == ChartRange.today) return;
    range = ChartRange.today;
    errorMessage = null;
    unawaited(load(initial: true));
    notifyListeners();
  }

  void setMetric(ChartMetric newMetric) {
    if (metric == newMetric) return;
    metric = newMetric;
    errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  void startSilentRefresh() {
    refreshTimer?.cancel();
    refreshTimer = Timer.periodic(
      const Duration(seconds: 10), (_) => unawaited(load()),
    );
  }

  void stopSilentRefresh() {
    refreshTimer?.cancel();
    refreshTimer = null;
  }


  @override
  void dispose() {
    stopSilentRefresh();
    super.dispose();
  }
}

class PreparedChartData {
  const PreparedChartData({
    required this.points,
    required this.unit,
    required this.min,
    required this.max,
    required this.average,
    required this.latestValue,
    required this.axisStart,
    required this.axisEnd,
    required this.yLabels,
    required this.xLabels,
  });

  final List<ChartPoint> points;
  final String unit;
  final double min;
  final double max;
  final double average;
  final double latestValue;
  final DateTime axisStart;
  final DateTime axisEnd;
  final List<double> yLabels;
  final List<DateTime> xLabels;
}

class ChartPoint {
  const ChartPoint({
    required this.time,
    required this.value,
  });

  final DateTime time;
  final double value;
}

PreparedChartData buildChartData({
  required List<Map<String, dynamic>> rows,
  required DateTime from,
  required DateTime now,
  required ChartRange range,
  required ChartMetric metric,
  double? maxSafetyValue,
}) {
  final axisStart = from;
  final axisEnd = now;

  final points = rows
      .map((row) {
    final ts = DateTime.tryParse((row['ts'] ?? '').toString())?.toLocal();
    if (ts == null) return null;

    double? value;
    switch (metric) {
      case ChartMetric.consumption:
        value = _toDouble(row['energy_wh']);
        break;
      case ChartMetric.power:
        value = _toDouble(row['power_w']);
        break;
      case ChartMetric.voltage:
        value = _toDouble(row['voltage_v']);
        break;
    }

    if (value == null) return null;

    return ChartPoint(time: ts, value: value);
  })
      .whereType<ChartPoint>()
      .where((point) => !point.time.isBefore(axisStart) && !point.time.isAfter(axisEnd))
      .toList()
    ..sort((a, b) => a.time.compareTo(b.time));

  if (points.isEmpty) {
    return PreparedChartData(
      points: const [],
      unit: chartMetricUnit(metric),
      min: 0,
      max: 0,
      average: 0,
      latestValue: 0,
      axisStart: axisStart,
      axisEnd: axisEnd,
      yLabels: const [0, 1, 2, 3, 4],
      xLabels: buildXAxisLabels(range, axisStart, axisEnd),
    );
  }

  final values = points.map((e) => e.value).toList();
  final min = values.reduce(math.min);
  final dataMax = values.reduce(math.max);
  final max = maxSafetyValue ?? dataMax;
  final sum = values.fold<double>(0, (acc, e) => acc + e);
  final average = sum / values.length;
  final latestValue = values.last;

  final yLabels = buildYAxisLabels(min: min, max: max);
  final xLabels = buildXAxisLabels(range, axisStart, axisEnd);

  return PreparedChartData(
    points: points,
    unit: chartMetricUnit(metric),
    min: min,
    max: max,
    average: average,
    latestValue: latestValue,
    axisStart: axisStart,
    axisEnd: axisEnd,
    yLabels: yLabels,
    xLabels: xLabels,
  );
}

List<double> buildYAxisLabels({
  required double min,
  required double max,
}) {
  if ((max - min).abs() < 0.0001) {
    final double base = max == 0 ? 1.0 : max.abs();
    return <double>[
      0.0,
      base * 0.25,
      base * 0.5,
      base * 0.75,
      base,
    ];
  }

  final double step = (max - min) / 4;
  return List<double>.generate(5, (index) => min + (step * index));
}

List<DateTime> buildXAxisLabels(
    ChartRange range,
    DateTime from,
    DateTime to,
    ) {
  switch (range) {
    case ChartRange.today:
      return List<DateTime>.generate(
        5,
            (index) => from.add(Duration(
          seconds: ((to.difference(from).inSeconds / 4) * index).round(),
        )),
      );
    case ChartRange.week:
      return List<DateTime>.generate(
        8,
            (index) => from.add(Duration(days: index)),
      );
    case ChartRange.month:
      return List<DateTime>.generate(
        7,
            (index) => from.add(Duration(days: index * 5)),
      );
  }
}

String formatChartValue(double value, String unit) {
  return '${value.toStringAsFixed(2)} $unit';
}

String chartMetricUnit(ChartMetric metric) {
  switch (metric) {
    case ChartMetric.consumption:
      return 'Wh';
    case ChartMetric.power:
      return 'W';
    case ChartMetric.voltage:
      return 'V';
  }
}

String chartMetricLabel(ChartMetric metric) {
  switch (metric) {
    case ChartMetric.consumption:
      return 'Consumo';
    case ChartMetric.power:
      return 'Potencia';
    case ChartMetric.voltage:
      return 'Voltaje';
  }
}

String chartRangeLabel(ChartRange range) {
  switch (range) {
    case ChartRange.today:
      return 'Hoy';
    case ChartRange.week:
      return 'Últimos 7 días';
    case ChartRange.month:
      return 'Últimos 30 días';
  }
}


String _buildRowsSignature(List<Map<String, dynamic>> rows) {
  final buffer = StringBuffer();

  for (final row in rows) {
    buffer
      ..write(row['ts'] ?? '')
      ..write('|')
      ..write(row['power_w'] ?? '')
      ..write('|')
      ..write(row['voltage_v'] ?? '')
      ..write('|')
      ..write(row['energy_wh'] ?? '')
      ..write(';');
  }

  return buffer.toString();
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

