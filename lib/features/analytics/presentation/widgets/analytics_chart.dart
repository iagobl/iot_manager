import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';

enum AnalyticsChartMode {
  todayBands,
  currentMoment,
  weekDays,
  rangePeriods,
}

class AnalyticsChart extends StatelessWidget {
  const AnalyticsChart({
    super.key,
    required this.series,
    required this.range,
    required this.mode,
    required this.showTodayModeSelector,
    required this.onModeChanged,
    this.normalizationLimits = AnalyticsNormalizationLimits.empty,
    this.aggregateMode = false,
  });

  final AnalyticsSeries series;
  final DateTimeRange range;
  final AnalyticsChartMode mode;
  final bool showTodayModeSelector;
  final ValueChanged<AnalyticsChartMode> onModeChanged;
  final AnalyticsNormalizationLimits normalizationLimits;
  final bool aggregateMode;

  @override
  Widget build(BuildContext context) {
    final buckets = _buildBuckets(series, range, mode);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(aggregateMode ? aggregateTitleForMode(mode) : titleForMode(mode),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(aggregateMode ? aggregateDescriptionForMode(mode) : descriptionForMode(mode),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (showTodayModeSelector) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ModeChip(
                  label: 'Franjas horarias',
                  selected: mode == AnalyticsChartMode.todayBands,
                  onTap: () => onModeChanged(AnalyticsChartMode.todayBands),
                ),
                ModeChip(
                  label: 'Momento actual',
                  selected: mode == AnalyticsChartMode.currentMoment,
                  onTap: () => onModeChanged(AnalyticsChartMode.currentMoment),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (aggregateMode) AggregateLegendRow(mode: mode) else const LegendRow(),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.45)),
            ),
            child: SizedBox(
              height: 320,
              width: double.infinity,
              child: CustomPaint(
                painter: aggregateMode && mode == AnalyticsChartMode.currentMoment
                    ? RealtimeAggregateLinePainter(
                  buckets: buckets,
                  textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ) ?? const TextStyle(fontSize: 11),
                ) : aggregateMode ? AggregateLinePainter(
                  buckets: buckets,
                  textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ) ?? const TextStyle(fontSize: 11),
                  gridColor: scheme.outlineVariant.withValues(alpha: 0.34),
                  mode: mode,
                ) : GroupedHistogramPainter(
                  buckets: buckets,
                  textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ) ?? const TextStyle(fontSize: 11),
                  gridColor: scheme.outlineVariant.withValues(alpha: 0.34),
                  mode: mode,
                  normalizationLimits: normalizationLimits,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String titleForMode(AnalyticsChartMode mode) {
    switch (mode) {
      case AnalyticsChartMode.todayBands:
        return 'Comparativa por franjas horarias';
      case AnalyticsChartMode.currentMoment:
        return 'Comparativa del momento actual';
      case AnalyticsChartMode.weekDays:
        return 'Comparativa diaria del periodo';
      case AnalyticsChartMode.rangePeriods:
        return 'Comparativa por periodos del rango';
    }
  }

  String descriptionForMode(AnalyticsChartMode mode) {
    switch (mode) {
      case AnalyticsChartMode.todayBands:
        return 'Agrupación del día actual por bloques horarios.';
      case AnalyticsChartMode.currentMoment:
        return 'Seguimiento de las últimas horas en intervalos recientes.';
      case AnalyticsChartMode.weekDays:
        return 'Una columna por cada día real del periodo seleccionado.';
      case AnalyticsChartMode.rangePeriods:
        return 'Agrupación del rango seleccionado en periodos consecutivos.';
    }
  }

  String aggregateTitleForMode(AnalyticsChartMode mode) {
    switch (mode) {
      case AnalyticsChartMode.todayBands:
        return 'Consumo por franjas horarias';
      case AnalyticsChartMode.currentMoment:
        return 'Potencia (W)';
      case AnalyticsChartMode.weekDays:
        return 'Consumo diario del periodo';
      case AnalyticsChartMode.rangePeriods:
        return 'Consumo por periodos del rango';
    }
  }

  String aggregateDescriptionForMode(AnalyticsChartMode mode) {
    switch (mode) {
      case AnalyticsChartMode.todayBands:
        return 'Media del consumo (Wh) por franja horaria del día.';
      case AnalyticsChartMode.currentMoment:
        return 'Seguimiento en tiempo real';
      case AnalyticsChartMode.weekDays:
        return 'Consumo diario para cada fecha real del periodo.';
      case AnalyticsChartMode.rangePeriods:
        return 'Consumo total por periodos consecutivos del rango seleccionado.';
    }
  }

  List<GroupedBucket> _buildBuckets(
      AnalyticsSeries series,
      DateTimeRange range,
      AnalyticsChartMode mode,
      ) {
    final points = [...series.points]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (points.isEmpty) return const [];

    switch (mode) {
      case AnalyticsChartMode.todayBands:
        return buildTodayBands(points);
      case AnalyticsChartMode.currentMoment:
        return buildCurrentMoment(points);
      case AnalyticsChartMode.weekDays:
        return buildDailyBuckets(points, range);
      case AnalyticsChartMode.rangePeriods:
        return buildRangePeriods(points, range);
    }
  }

  List<GroupedBucket> buildTodayBands(List<AnalyticsPoint> points) {
    const labels = ['00-03', '04-07', '08-11', '12-15', '16-19', '20-23'];

    final powerSums = List<double>.filled(6, 0.0);
    final voltageSums = List<double>.filled(6, 0.0);
    final currentSums = List<double>.filled(6, 0.0);
    final counts = List<int>.filled(6, 0);

    for (final point in points) {
      final local = point.timestamp.toLocal();
      final bucket = local.hour ~/ 4;
      powerSums[bucket] += point.powerW;
      voltageSums[bucket] += point.voltageV;
      currentSums[bucket] += point.currentA;
      counts[bucket] += 1;
    }

    final energyAverages = aggregatePositiveEnergyDeltasAverage(
      points: points,
      bucketCount: 6,
      bucketForPoint: (point) => point.timestamp.toLocal().hour ~/ 4,
    );

    return List.generate(6, (index) {
      final count = counts[index];
      return GroupedBucket(
        label: labels[index],
        timestamp: null,
        power: count == 0 ? 0.0 : powerSums[index] / count,
        voltage: count == 0 ? 0.0 : voltageSums[index] / count,
        current: count == 0 ? 0.0 : currentSums[index] / count,
        energy: energyAverages[index],
      );
    });
  }

  List<GroupedBucket> buildCurrentMoment(List<AnalyticsPoint> points) {
    final sorted = [...points]..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return sorted.map((point) {
      final local = point.timestamp.toLocal();
      return GroupedBucket(
        label: '${two(local.hour)}:${two(local.minute)}',
        timestamp: local,
        power: point.powerW,
        voltage: point.voltageV,
        current: point.currentA,
        energy: point.energyWh,
      );
    }).toList();
  }

  List<GroupedBucket> buildDailyBuckets(
      List<AnalyticsPoint> points,
      DateTimeRange range,
      ) {
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    );

    final totalDays = end.difference(start).inDays + 1;
    final powerSums = List<double>.filled(totalDays, 0.0);
    final voltageSums = List<double>.filled(totalDays, 0.0);
    final currentSums = List<double>.filled(totalDays, 0.0);
    final counts = List<int>.filled(totalDays, 0);

    int bucketForPoint(AnalyticsPoint point) {
      final localDay = DateTime(
        point.timestamp.toLocal().year,
        point.timestamp.toLocal().month,
        point.timestamp.toLocal().day,
      );
      return localDay.difference(start).inDays;
    }

    for (final point in points) {
      final bucket = bucketForPoint(point);
      if (bucket < 0 || bucket >= totalDays) continue;

      powerSums[bucket] += point.powerW;
      voltageSums[bucket] += point.voltageV;
      currentSums[bucket] += point.currentA;
      counts[bucket] += 1;
    }

    final energyTotals = aggregatePositiveEnergyDeltasTotal(
      points: points,
      bucketCount: totalDays,
      bucketForPoint: (point) {
        final bucket = bucketForPoint(point);
        if (bucket < 0 || bucket >= totalDays) return null;
        return bucket;
      },
    );

    return List.generate(totalDays, (index) {
      final day = start.add(Duration(days: index));
      final count = counts[index];

      return GroupedBucket(
        label: '${two(day.day)}/${two(day.month)}',
        timestamp: day,
        power: count == 0 ? 0.0 : powerSums[index] / count,
        voltage: count == 0 ? 0.0 : voltageSums[index] / count,
        current: count == 0 ? 0.0 : currentSums[index] / count,
        energy: energyTotals[index],
      );
    });
  }

  List<GroupedBucket> buildRangePeriods(
      List<AnalyticsPoint> points,
      DateTimeRange range,
      ) {
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
      23,
      59,
      59,
      999,
    );

    final totalDays = end.difference(start).inDays + 1;

    if (totalDays <= 14) {
      return buildDailyBuckets(points, range);
    }

    final bucketCount = math.min(10, totalDays);
    final powerSums = List<double>.filled(bucketCount, 0.0);
    final voltageSums = List<double>.filled(bucketCount, 0.0);
    final currentSums = List<double>.filled(bucketCount, 0.0);
    final counts = List<int>.filled(bucketCount, 0);

    int bucketForTimestamp(DateTime timestamp) {
      final localDay = DateTime(
        timestamp.toLocal().year,
        timestamp.toLocal().month,
        timestamp.toLocal().day,
      );
      final dayOffset = localDay.difference(start).inDays.clamp(0, totalDays - 1);
      final ratio = dayOffset / math.max(1, totalDays);
      return math.min(bucketCount - 1, (ratio * bucketCount).floor());
    }

    for (final point in points) {
      final bucket = bucketForTimestamp(point.timestamp);
      powerSums[bucket] += point.powerW;
      voltageSums[bucket] += point.voltageV;
      currentSums[bucket] += point.currentA;
      counts[bucket] += 1;
    }

    final energySums = aggregatePositiveEnergyDeltasTotal(
      points: points,
      bucketCount: bucketCount,
      bucketForPoint: (point) => bucketForTimestamp(point.timestamp),
    );

    return List.generate(bucketCount, (index) {
      final startDayOffset = ((totalDays / bucketCount) * index).floor();
      final endDayOffset =
      math.min(totalDays - 1, ((totalDays / bucketCount) * (index + 1)).ceil() - 1);

      final sliceStart = start.add(Duration(days: startDayOffset));
      final sliceEnd = start.add(Duration(days: endDayOffset));
      final count = counts[index];

      final label = sliceStart.day == sliceEnd.day && sliceStart.month == sliceEnd.month
          ? '${two(sliceStart.day)}/${two(sliceStart.month)}'
          : '${two(sliceStart.day)}/${two(sliceStart.month)}-${two(sliceEnd.day)}/${two(sliceEnd.month)}';

      return GroupedBucket(
        label: label,
        timestamp: sliceStart,
        power: count == 0 ? 0.0 : powerSums[index] / count,
        voltage: count == 0 ? 0.0 : voltageSums[index] / count,
        current: count == 0 ? 0.0 : currentSums[index] / count,
        energy: energySums[index],
      );
    });
  }

  List<double> aggregatePositiveEnergyDeltasTotal({
    required List<AnalyticsPoint> points,
    required int bucketCount,
    required int? Function(AnalyticsPoint point) bucketForPoint,
  }) {
    final totals = List<double>.filled(bucketCount, 0.0);
    final groupedByDevice = <String, List<AnalyticsPoint>>{};

    for (final point in points) {
      final deviceId = point.deviceId;
      if (deviceId == null || deviceId.isEmpty) continue;
      groupedByDevice.putIfAbsent(deviceId, () => <AnalyticsPoint>[]).add(point);
    }

    for (final devicePoints in groupedByDevice.values) {
      devicePoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      for (int i = 1; i < devicePoints.length; i++) {
        final previous = devicePoints[i - 1];
        final current = devicePoints[i];
        final delta = current.energyWh - previous.energyWh;

        if (!delta.isFinite || delta <= 0) continue;

        final bucket = bucketForPoint(current);
        if (bucket == null || bucket < 0 || bucket >= bucketCount) continue;
        totals[bucket] += delta;
      }
    }
    return totals;
  }

  List<double> aggregatePositiveEnergyDeltasAverage({
    required List<AnalyticsPoint> points,
    required int bucketCount,
    required int? Function(AnalyticsPoint point) bucketForPoint,
  }) {
    final totals = List<double>.filled(bucketCount, 0.0);
    final counts = List<int>.filled(bucketCount, 0);
    final groupedByDevice = <String, List<AnalyticsPoint>>{};

    for (final point in points) {
      final deviceId = point.deviceId;
      if (deviceId == null || deviceId.isEmpty) continue;
      groupedByDevice.putIfAbsent(deviceId, () => <AnalyticsPoint>[]).add(point);
    }

    for (final devicePoints in groupedByDevice.values) {
      devicePoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      for (int i = 1; i < devicePoints.length; i++) {
        final previous = devicePoints[i - 1];
        final current = devicePoints[i];
        final delta = current.energyWh - previous.energyWh;

        if (!delta.isFinite || delta <= 0) continue;

        final bucket = bucketForPoint(current);
        if (bucket == null || bucket < 0 || bucket >= bucketCount) continue;

        totals[bucket] += delta;
        counts[bucket] += 1;
      }
    }

    return List<double>.generate(
      bucketCount, (index) => counts[index] == 0 ? 0.0 : totals[index] / counts[index],
    );
  }

  String two(int value) => value.toString().padLeft(2, '0');
}

class GroupedBucket {
  const GroupedBucket({
    required this.label,
    required this.timestamp,
    required this.power,
    required this.voltage,
    required this.current,
    required this.energy,
  });

  final String label;
  final DateTime? timestamp;
  final double power;
  final double voltage;
  final double current;
  final double energy;
}

class GroupedHistogramPainter extends CustomPainter {
  GroupedHistogramPainter({
    required this.buckets,
    required this.textStyle,
    required this.gridColor,
    required this.mode,
    required this.normalizationLimits,
  });

  final List<GroupedBucket> buckets;
  final TextStyle textStyle;
  final Color gridColor;
  final AnalyticsChartMode mode;
  final AnalyticsNormalizationLimits normalizationLimits;

  static const powerColor = Color(0xFF2563EB);
  static const voltageColor = Color(0xFF7C3AED);
  static const currentColor = Color(0xFF14B8A6);

  @override
  void paint(Canvas canvas, Size size) {
    final leftPadding = 46.0;
    final rightPadding = 12.0;
    final topPadding = 12.0;
    final bottomPadding = 34.0;

    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );

    final yTicks = const [0.0, 0.25, 0.5, 0.75, 1.0];

    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;

    for (final tick in yTicks) {
      final y = chartRect.bottom - (chartRect.height * tick);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );

      final label = '${(tick * 100).round()}%';
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(0, y - (tp.height / 2)));
    }

    final axisPaint = Paint()..color = gridColor.withValues(alpha: 0.9)..strokeWidth = 1.2;

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );

    if (buckets.isEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'No hay datos para este periodo',
          style: textStyle.copyWith(fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);

      tp.paint(canvas, Offset(
          (size.width - tp.width) / 2,
          (size.height - tp.height) / 2,
        ),
      );
      return;
    }

    final maxPower = buckets.fold<double>(0, (max, item) => math.max(max, item.power));
    final maxVoltage = buckets.fold<double>(0, (max, item) => math.max(max, item.voltage));
    final maxCurrent = buckets.fold<double>(0, (max, item) => math.max(max, item.current));

    final normalizationPower = normalizationLimits.powerW > 0 ? normalizationLimits.powerW : maxPower;
    final normalizationVoltage = normalizationLimits.voltageV > 0 ? normalizationLimits.voltageV : maxVoltage;
    final normalizationCurrent = normalizationLimits.currentA > 0 ? normalizationLimits.currentA : maxCurrent;

    final bucketWidth = chartRect.width / buckets.length;
    final groupWidth = bucketWidth * 0.60;
    final barWidth = groupWidth / 3;

    final powerPaint = Paint()..color = powerColor;
    final voltagePaint = Paint()..color = voltageColor;
    final currentPaint = Paint()..color = currentColor;

    for (int i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      final baseX = chartRect.left + (bucketWidth * i) + ((bucketWidth - groupWidth) / 2);

      final powerRatio = normalizedRatio(bucket.power, normalizationPower);
      final voltageRatio = normalizedRatio(bucket.voltage, normalizationVoltage);
      final currentRatio = normalizedRatio(bucket.current, normalizationCurrent);

      drawBar(
        canvas: canvas,
        rect: Rect.fromLTWH(
          baseX,
          chartRect.bottom - (chartRect.height * powerRatio),
          barWidth,
          chartRect.height * powerRatio,
        ),
        paint: powerPaint,
      );

      drawBar(
        canvas: canvas,
        rect: Rect.fromLTWH(
          baseX + barWidth,
          chartRect.bottom - (chartRect.height * voltageRatio),
          barWidth,
          chartRect.height * voltageRatio,
        ),
        paint: voltagePaint,
      );

      drawBar(
        canvas: canvas,
        rect: Rect.fromLTWH(
          baseX + (barWidth * 2),
          chartRect.bottom - (chartRect.height * currentRatio),
          barWidth,
          chartRect.height * currentRatio,
        ),
        paint: currentPaint,
      );

      final shouldPaintLabel = _shouldPaintLabel(i, buckets.length, mode);
      if (!shouldPaintLabel) continue;

      final labelWidth = bucketWidth.clamp(24.0, 54.0);

      final tp = TextPainter(
        text: TextSpan(
          text: bucket.label,
          style: textStyle.copyWith(
            fontSize: mode == AnalyticsChartMode.weekDays ? 9 : textStyle.fontSize,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
      )..layout(minWidth: labelWidth, maxWidth: labelWidth);

      final dx = (baseX + (groupWidth / 2) - (labelWidth / 2)).clamp(
        chartRect.left,
        chartRect.right - labelWidth,
      );

      tp.paint(canvas, Offset(dx, chartRect.bottom + 8));
    }
  }

  void drawBar({
    required Canvas canvas,
    required Rect rect,
    required Paint paint,
  }) {
    if (rect.height <= 0) return;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), paint);
  }

  double normalizedRatio(double value, double normalizationValue) {
    if (normalizationValue <= 0) return 0;
    return (value / normalizationValue).clamp(0.0, 1.0);
  }

  bool _shouldPaintLabel(int index, int total, AnalyticsChartMode mode) {
    switch (mode) {
      case AnalyticsChartMode.currentMoment:
        if (total <= 8) return true;
        if (total <= 16) return index.isEven || index == total - 1;
        return index % 3 == 0 || index == total - 1;
      case AnalyticsChartMode.todayBands:
        return true;
      case AnalyticsChartMode.weekDays:
        if (total <= 8) return true;
        return index.isEven || index == total - 1;
      case AnalyticsChartMode.rangePeriods:
        if (total <= 6) return true;
        return index % 2 == 0 || index == total - 1;
    }
  }

  @override
  bool shouldRepaint(covariant GroupedHistogramPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.mode != mode ||
        oldDelegate.normalizationLimits != normalizationLimits;
  }
}

class AggregateLinePainter extends CustomPainter {
  AggregateLinePainter({
    required this.buckets,
    required this.textStyle,
    required this.gridColor,
    required this.mode,
  });

  final List<GroupedBucket> buckets;
  final TextStyle textStyle;
  final Color gridColor;
  final AnalyticsChartMode mode;

  static const lineColor = Color(0xFF2563EB);

  @override
  void paint(Canvas canvas, Size size) {
    final leftPadding = 46.0;
    final rightPadding = 12.0;
    final topPadding = 12.0;
    final bottomPadding = 40.0;

    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );

    if (buckets.isEmpty) {
      final tp = TextPainter(
        text: TextSpan(text: 'No hay datos para este periodo',
          style: textStyle.copyWith(fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);

      tp.paint(canvas,
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
      );
      return;
    }

    final values = buckets.map((bucket) => bucket.energy).toList();
    final maxValue = values.fold<double>(0, math.max);
    final minValue = values.fold<double>(double.infinity, math.min);
    final safeMinValue = minValue == double.infinity ? 0.0 : minValue;
    final valueRange = (maxValue - safeMinValue).abs() < 0.0001 ? math.max(1.0, maxValue) : (maxValue - safeMinValue);

    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;

    const gridLines = 5;
    for (int i = 0; i < gridLines; i++) {
      final ratio = i / (gridLines - 1);
      final y = chartRect.bottom - (chartRect.height * ratio);
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);

      final value = safeMinValue + (valueRange * ratio);
      final label = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(0, y - (tp.height / 2)));
    }

    final axisPaint = Paint()..color = gridColor.withValues(alpha: 0.9)..strokeWidth = 1.2;

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );

    final pointSpacing = buckets.length == 1 ? 0.0 : chartRect.width / (buckets.length - 1);
    final linePaint = Paint()..color = lineColor..strokeWidth = 2.2..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = lineColor..style = PaintingStyle.fill;

    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < buckets.length; i++) {
      final value = buckets[i].energy;
      final normalized = ((value - safeMinValue) / valueRange).clamp(0.0, 1.0);
      final x = chartRect.left + (pointSpacing * i);
      final y = chartRect.bottom - (chartRect.height * normalized);
      final offset = Offset(x, y);
      points.add(offset);

      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }

    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 3.5, pointPaint);
      canvas.drawCircle(point, 5.5,
        Paint()..color = lineColor.withValues(alpha: 0.16)..style = PaintingStyle.fill,
      );
    }

    final labelWidth = buckets.length <= 1
        ? 40.0
        : (chartRect.width / buckets.length).clamp(24.0, 54.0);

    for (int i = 0; i < buckets.length; i++) {
      final shouldPaintLabel = _shouldPaintLabel(i, buckets.length, mode);
      if (!shouldPaintLabel) continue;

      final label = buckets[i].label;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: textStyle.copyWith(
            fontSize: mode == AnalyticsChartMode.weekDays ? 9 : textStyle.fontSize,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
      )..layout(minWidth: labelWidth, maxWidth: labelWidth);

      final dx = (points[i].dx - (labelWidth / 2)).clamp(
        chartRect.left,
        chartRect.right - labelWidth,
      );

      tp.paint(canvas, Offset(dx, chartRect.bottom + 8));
    }
  }

  bool _shouldPaintLabel(int index, int total, AnalyticsChartMode mode) {
    switch (mode) {
      case AnalyticsChartMode.currentMoment:
        if (total <= 8) return true;
        if (total <= 16) return index.isEven || index == total - 1;
        return index % 3 == 0 || index == total - 1;
      case AnalyticsChartMode.todayBands:
        return true;
      case AnalyticsChartMode.weekDays:
        if (total <= 8) return true;
        return index.isEven || index == total - 1;
      case AnalyticsChartMode.rangePeriods:
        if (total <= 6) return true;
        return index % 2 == 0 || index == total - 1;
    }
  }

  @override
  bool shouldRepaint(covariant AggregateLinePainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.mode != mode;
  }
}

class RealtimeAggregateLinePainter extends CustomPainter {
  RealtimeAggregateLinePainter({
    required this.buckets,
    required this.textStyle,
  });

  final List<GroupedBucket> buckets;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final leftPad = 52.0;
    final rightPad = 18.0;
    final topPad = 10.0;
    final bottomPad = 34.0;

    final chartRect = Rect.fromLTRB(
      leftPad,
      topPad,
      size.width - rightPad,
      size.height - bottomPad,
    );

    if (chartRect.width <= 0 || chartRect.height <= 0 || buckets.isEmpty) {
      return;
    }

    final pointsData = buckets.where((e) => e.timestamp != null).toList()
      ..sort((a, b) => a.timestamp!.compareTo(b.timestamp!));

    if (pointsData.isEmpty) return;

    final axisStartMs = pointsData.first.timestamp!.millisecondsSinceEpoch.toDouble();
    final axisEndMs = pointsData.last.timestamp!.millisecondsSinceEpoch.toDouble();
    final axisRangeMs = math.max(1.0, axisEndMs - axisStartMs);

    var minY = pointsData.map((e) => e.power).reduce(math.min);
    var maxY = pointsData.map((e) => e.power).reduce(math.max);

    if ((maxY - minY).abs() < 0.0001) {
      minY -= 1;
      maxY += 1;
    } else {
      final pad = (maxY - minY) * 0.14;
      minY -= pad;
      maxY += pad;
    }

    final yRange = math.max(1.0, maxY - minY);

    final gridPaint = Paint()..color = Colors.black.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke..strokeWidth = 1;

    const horizontalLines = 6;
    for (int i = 0; i <= horizontalLines; i++) {
      final y = chartRect.top + (chartRect.height * i / horizontalLines);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final xTicks = buildXAxisTicks(pointsData.first.timestamp!, pointsData.last.timestamp!);

    for (final tick in xTicks) {
      final x = xForDate(tick, chartRect, axisStartMs, axisRangeMs);
      canvas.drawLine(Offset(x, chartRect.top), Offset(x, chartRect.bottom), gridPaint);
    }

    final axisPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    canvas.drawLine(
      Offset(chartRect.left, chartRect.top),
      Offset(chartRect.left, chartRect.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );

    if (pointsData.length == 1) {
      final only = pointsData.first;
      final x = xForDate(only.timestamp!, chartRect, axisStartMs, axisRangeMs);
      final y = yForValue(only.power, chartRect, minY, yRange);

      canvas.drawCircle(Offset(x, y), 3,
        Paint()..color = Colors.blue.withValues(alpha: 0.92),
      );
    } else {
      final path = Path();
      final fillPath = Path();

      for (int i = 0; i < pointsData.length; i++) {
        final point = pointsData[i];
        final x = xForDate(point.timestamp!, chartRect, axisStartMs, axisRangeMs);
        final y = yForValue(point.power, chartRect, minY, yRange);

        if (i == 0) {
          path.moveTo(x, y);
          fillPath.moveTo(x, chartRect.bottom);
          fillPath.lineTo(x, y);
        } else {
          path.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
      }

      final lastPoint = pointsData.last;
      final lastX = xForDate(lastPoint.timestamp!, chartRect, axisStartMs, axisRangeMs);
      fillPath.lineTo(lastX, chartRect.bottom);
      fillPath.close();

      final fillPaint = Paint()..color = Colors.blue.withValues(alpha: 0.08)..style = PaintingStyle.fill;

      final linePaint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);

      final lp = pointsData.last;
      final lx = xForDate(lp.timestamp!, chartRect, axisStartMs, axisRangeMs);
      final ly = yForValue(lp.power, chartRect, minY, yRange);

      canvas.drawCircle(Offset(lx, ly), 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(lx, ly), 4.5,
        Paint()..color = Colors.blue.withValues(alpha: 0.96)..style = PaintingStyle.stroke..strokeWidth = 2,
      );
    }

    drawYLabels(canvas, chartRect, minY, maxY);
    drawXLabels(canvas, chartRect, xTicks, axisStartMs, axisRangeMs);
  }

  double xForDate(DateTime date, Rect chartRect, double axisStartMs, double axisRangeMs) {
    final currentMs = date.millisecondsSinceEpoch.toDouble();
    final ratio = ((currentMs - axisStartMs) / axisRangeMs).clamp(0.0, 1.0);
    return chartRect.left + (chartRect.width * ratio);
  }

  double yForValue(double value, Rect chartRect, double minY, double yRange) {
    final normY = ((value - minY) / yRange).clamp(0.0, 1.0);
    return chartRect.bottom - (normY * chartRect.height);
  }

  List<DateTime> buildXAxisTicks(DateTime start, DateTime end) {
    if (start.isAtSameMomentAs(end)) {
      return [start];
    }

    return List.generate(5, (i) {
      final ratio = i / 4;
      final millis = start.millisecondsSinceEpoch +
          ((end.millisecondsSinceEpoch - start.millisecondsSinceEpoch) * ratio).round();
      return DateTime.fromMillisecondsSinceEpoch(millis);
    });
  }

  void drawYLabels(Canvas canvas, Rect chartRect, double minY, double maxY) {
    const steps = 6;

    for (int i = 0; i <= steps; i++) {
      final value = maxY - ((maxY - minY) * i / steps);
      final y = chartRect.top + (chartRect.height * i / steps);

      final tp = TextPainter(
        text: TextSpan(
          text: compactNumber(value),
          style: const TextStyle(color: Colors.black87, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: chartRect.left - 8);

      tp.paint(canvas, Offset(chartRect.left - tp.width - 10, y - tp.height / 2));
    }
  }

  void drawXLabels(Canvas canvas, Rect chartRect, List<DateTime> ticks,
      double axisStartMs, double axisRangeMs) {
    for (final tick in ticks) {
      final x = xForDate(tick, chartRect, axisStartMs, axisRangeMs);

      final tp = TextPainter(
        text: TextSpan(
          text: '${tick.hour.toString().padLeft(2, '0')}:${tick.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(color: Colors.black87, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 54);

      var dx = x - tp.width / 2;

      if (dx < chartRect.left) dx = chartRect.left;
      if (dx + tp.width > chartRect.right) {
        dx = chartRect.right - tp.width;
      }

      tp.paint(canvas, Offset(dx, chartRect.bottom + 8));
    }
  }

  String compactNumber(double value) {
    if (value.abs() >= 100) return value.toStringAsFixed(0);
    if (value.abs() >= 10) return value.toStringAsFixed(1);
    return value.toStringAsFixed(2);
  }

  @override
  bool shouldRepaint(covariant RealtimeAggregateLinePainter oldDelegate) {
    return oldDelegate.buckets != buckets || oldDelegate.textStyle != textStyle;
  }
}

class LegendRow extends StatelessWidget {
  const LegendRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        LegendItem(color: GroupedHistogramPainter.powerColor, label: 'Potencia'),
        LegendItem(color: GroupedHistogramPainter.voltageColor, label: 'Voltaje'),
        LegendItem(color: GroupedHistogramPainter.currentColor, label: 'Corriente'),
      ],
    );
  }
}

class AggregateLegendRow extends StatelessWidget {
  const AggregateLegendRow({super.key, required this.mode});

  final AnalyticsChartMode mode;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        LegendItem(
          color: const Color(0xFF2563EB),
          label: mode == AnalyticsChartMode.currentMoment ? 'Potencia' : 'Consumo',
        ),
      ],
    );
  }
}

class LegendItem extends StatelessWidget {
  const LegendItem({
    super.key,
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class ModeChip extends StatelessWidget {
  const ModeChip({super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
