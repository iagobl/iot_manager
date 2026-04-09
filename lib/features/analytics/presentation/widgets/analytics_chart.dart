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
        color: scheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            aggregateMode ? _aggregateTitleForMode(mode) : _titleForMode(mode),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            aggregateMode ? _aggregateDescriptionForMode(mode)
                : _descriptionForMode(mode),
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
                _ModeChip(
                  label: 'Franjas horarias',
                  selected: mode == AnalyticsChartMode.todayBands,
                  onTap: () => onModeChanged(AnalyticsChartMode.todayBands),
                ),
                _ModeChip(
                  label: 'Momento actual',
                  selected: mode == AnalyticsChartMode.currentMoment,
                  onTap: () => onModeChanged(AnalyticsChartMode.currentMoment),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (aggregateMode) const _AggregateLegendRow() else const _LegendRow(),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest.withOpacity(0.80),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withOpacity(0.45),
              ),
            ),
            child: SizedBox(
              height: 320,
              width: double.infinity,
              child: CustomPaint(
                painter: aggregateMode ? _AggregateLinePainter(
                  buckets: buckets,
                  textStyle:
                  Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ) ??
                      const TextStyle(fontSize: 11),
                  gridColor: scheme.outlineVariant.withOpacity(0.34),
                  mode: mode,
                )
                    : _GroupedHistogramPainter(
                  buckets: buckets,
                  textStyle:
                  Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ) ??
                      const TextStyle(fontSize: 11),
                  gridColor: scheme.outlineVariant.withOpacity(0.34),
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

  String _titleForMode(AnalyticsChartMode mode) {
    switch (mode) {
      case AnalyticsChartMode.todayBands:
        return 'Comparativa por franjas horarias';
      case AnalyticsChartMode.currentMoment:
        return 'Comparativa del momento actual';
      case AnalyticsChartMode.weekDays:
        return 'Comparativa de la semana actual';
      case AnalyticsChartMode.rangePeriods:
        return 'Comparativa por periodos del rango';
    }
  }

  String _descriptionForMode(AnalyticsChartMode mode) {
    switch (mode) {
      case AnalyticsChartMode.todayBands:
        return 'Agrupación del día actual por bloques horarios.';
      case AnalyticsChartMode.currentMoment:
        return 'Seguimiento de las últimas 4 horas en intervalos de 20 minutos.';
      case AnalyticsChartMode.weekDays:
        return 'Media diaria de la semana actual.';
      case AnalyticsChartMode.rangePeriods:
        return 'Media por periodos temporales del rango seleccionado.';
    }
  }

  String _aggregateTitleForMode(AnalyticsChartMode mode) {
    switch (mode) {
      case AnalyticsChartMode.todayBands:
        return 'Consumo por franjas horarias';
      case AnalyticsChartMode.currentMoment:
        return 'Consumo del momento actual';
      case AnalyticsChartMode.weekDays:
        return 'Consumo de la semana actual';
      case AnalyticsChartMode.rangePeriods:
        return 'Consumo por periodos del rango';
    }
  }

  String _aggregateDescriptionForMode(AnalyticsChartMode mode) {
    switch (mode) {
      case AnalyticsChartMode.todayBands:
        return 'Seguimiento del consumo agrupado por franjas del día.';
      case AnalyticsChartMode.currentMoment:
        return 'Seguimiento del consumo agrupado en intervalos recientes.';
      case AnalyticsChartMode.weekDays:
        return 'Evolución del consumo diario de la semana actual.';
      case AnalyticsChartMode.rangePeriods:
        return 'Evolución del consumo total por periodos del rango seleccionado.';
    }
  }

  List<_GroupedBucket> _buildBuckets(
      AnalyticsSeries series,
      DateTimeRange range,
      AnalyticsChartMode mode,
      ) {
    final points = [...series.points]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (points.isEmpty) return const [];

    switch (mode) {
      case AnalyticsChartMode.todayBands:
        return _buildTodayBands(points);
      case AnalyticsChartMode.currentMoment:
        return _buildCurrentMoment(points);
      case AnalyticsChartMode.weekDays:
        return _buildWeekDays(points);
      case AnalyticsChartMode.rangePeriods:
        return _buildRangePeriods(points, range);
    }
  }

  List<_GroupedBucket> _buildTodayBands(List<AnalyticsPoint> points) {
    const labels = ['00-03', '04-07', '08-11', '12-15', '16-19', '20-23'];

    final powerSums = List<double>.filled(6, 0.0);
    final voltageSums = List<double>.filled(6, 0.0);
    final currentSums = List<double>.filled(6, 0.0);
    final energySums = List<double>.filled(6, 0.0);
    final counts = List<int>.filled(6, 0);

    for (final point in points) {
      final local = point.timestamp.toLocal();
      final bucket = local.hour ~/ 4;
      powerSums[bucket] += point.powerW;
      voltageSums[bucket] += point.voltageV;
      currentSums[bucket] += point.currentA;
      energySums[bucket] += point.energyWh;
      counts[bucket] += 1;
    }

    return List.generate(6, (index) {
      final count = counts[index];
      return _GroupedBucket(
        label: labels[index],
        power: count == 0 ? 0.0 : powerSums[index] / count,
        voltage: count == 0 ? 0.0 : voltageSums[index] / count,
        current: count == 0 ? 0.0 : currentSums[index] / count,
        energy: energySums[index],
      );
    });
  }

  List<_GroupedBucket> _buildCurrentMoment(List<AnalyticsPoint> points) {
    final latestLocal = points.last.timestamp.toLocal();

    const intervalMinutes = 20;
    const totalBuckets = 12;

    final alignedMinute = (latestLocal.minute ~/ intervalMinutes) * intervalMinutes;

    final alignedEnd = DateTime(
      latestLocal.year,
      latestLocal.month,
      latestLocal.day,
      latestLocal.hour,
      alignedMinute,
    );

    final start = alignedEnd.subtract(const Duration(minutes: 220));

    final powerSums = List<double>.filled(totalBuckets, 0.0);
    final voltageSums = List<double>.filled(totalBuckets, 0.0);
    final currentSums = List<double>.filled(totalBuckets, 0.0);
    final energySums = List<double>.filled(totalBuckets, 0.0);
    final counts = List<int>.filled(totalBuckets, 0);

    for (final point in points) {
      final local = point.timestamp.toLocal();

      if (local.isBefore(start) ||
          local.isAfter(alignedEnd.add(const Duration(minutes: 19, seconds: 59)))) {
        continue;
      }

      final diffMinutes = local.difference(start).inMinutes;
      final bucket = diffMinutes ~/ intervalMinutes;

      if (bucket >= 0 && bucket < totalBuckets) {
        powerSums[bucket] += point.powerW;
        voltageSums[bucket] += point.voltageV;
        currentSums[bucket] += point.currentA;
        energySums[bucket] += point.energyWh;
        counts[bucket] += 1;
      }
    }

    return List.generate(totalBuckets, (index) {
      final slotTime = start.add(Duration(minutes: index * intervalMinutes));
      final label =
          '${slotTime.hour.toString().padLeft(2, '0')}:${slotTime.minute.toString().padLeft(2, '0')}';
      final count = counts[index];

      return _GroupedBucket(
        label: label,
        power: count == 0 ? 0.0 : powerSums[index] / count,
        voltage: count == 0 ? 0.0 : voltageSums[index] / count,
        current: count == 0 ? 0.0 : currentSums[index] / count,
        energy: energySums[index],
      );
    });
  }

  List<_GroupedBucket> _buildWeekDays(List<AnalyticsPoint> points) {
    const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    final powerSums = List<double>.filled(7, 0.0);
    final voltageSums = List<double>.filled(7, 0.0);
    final currentSums = List<double>.filled(7, 0.0);
    final energySums = List<double>.filled(7, 0.0);
    final counts = List<int>.filled(7, 0);

    for (final point in points) {
      final local = point.timestamp.toLocal();
      final weekdayIndex = local.weekday - 1;
      powerSums[weekdayIndex] += point.powerW;
      voltageSums[weekdayIndex] += point.voltageV;
      currentSums[weekdayIndex] += point.currentA;
      energySums[weekdayIndex] += point.energyWh;
      counts[weekdayIndex] += 1;
    }

    return List.generate(7, (index) {
      final count = counts[index];
      return _GroupedBucket(
        label: labels[index],
        power: count == 0 ? 0.0 : powerSums[index] / count,
        voltage: count == 0 ? 0.0 : voltageSums[index] / count,
        current: count == 0 ? 0.0 : currentSums[index] / count,
        energy: energySums[index],
      );
    });
  }

  List<_GroupedBucket> _buildRangePeriods(
      List<AnalyticsPoint> points,
      DateTimeRange range,
      ) {
    final totalDays = range.end.difference(range.start).inDays + 1;
    final desiredBuckets = totalDays <= 10 ? totalDays : 10;
    final bucketCount = math.max(1, desiredBuckets);

    final powerSums = List<double>.filled(bucketCount, 0.0);
    final voltageSums = List<double>.filled(bucketCount, 0.0);
    final currentSums = List<double>.filled(bucketCount, 0.0);
    final energySums = List<double>.filled(bucketCount, 0.0);
    final counts = List<int>.filled(bucketCount, 0);

    final totalMillis = math.max(
      1,
      range.end.millisecondsSinceEpoch - range.start.millisecondsSinceEpoch,
    );

    for (final point in points) {
      final clampedMillis = point.timestamp.millisecondsSinceEpoch.clamp(
        range.start.millisecondsSinceEpoch,
        range.end.millisecondsSinceEpoch,
      );
      final ratio = (clampedMillis - range.start.millisecondsSinceEpoch) / totalMillis;
      final bucket = math.min(bucketCount - 1, (ratio * bucketCount).floor());

      powerSums[bucket] += point.powerW;
      voltageSums[bucket] += point.voltageV;
      currentSums[bucket] += point.currentA;
      energySums[bucket] += point.energyWh;
      counts[bucket] += 1;
    }

    return List.generate(bucketCount, (index) {
      final sliceStart = range.start.add(
        Duration(
          milliseconds: ((totalMillis / bucketCount) * index).round(),
        ),
      );
      final label =
          '${sliceStart.day.toString().padLeft(2, '0')}/${sliceStart.month.toString().padLeft(2, '0')}';

      final count = counts[index];
      return _GroupedBucket(
        label: label,
        power: count == 0 ? 0.0 : powerSums[index] / count,
        voltage: count == 0 ? 0.0 : voltageSums[index] / count,
        current: count == 0 ? 0.0 : currentSums[index] / count,
        energy: energySums[index],
      );
    });
  }
}

class _GroupedBucket {
  const _GroupedBucket({
    required this.label,
    required this.power,
    required this.voltage,
    required this.current,
    required this.energy,
  });

  final String label;
  final double power;
  final double voltage;
  final double current;
  final double energy;
}

class _GroupedHistogramPainter extends CustomPainter {
  _GroupedHistogramPainter({
    required this.buckets,
    required this.textStyle,
    required this.gridColor,
    required this.mode,
    required this.normalizationLimits,
  });

  final List<_GroupedBucket> buckets;
  final TextStyle textStyle;
  final Color gridColor;
  final AnalyticsChartMode mode;
  final AnalyticsNormalizationLimits normalizationLimits;

  static const _powerColor = Color(0xFF2563EB);
  static const _voltageColor = Color(0xFF7C3AED);
  static const _currentColor = Color(0xFF14B8A6);

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

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

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

    final axisPaint = Paint()
      ..color = gridColor.withOpacity(0.9)
      ..strokeWidth = 1.2;

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

      tp.paint(
        canvas,
        Offset(
          (size.width - tp.width) / 2,
          (size.height - tp.height) / 2,
        ),
      );
      return;
    }

    final maxPower = buckets.fold<double>(0, (max, item) => math.max(max, item.power));
    final maxVoltage =
    buckets.fold<double>(0, (max, item) => math.max(max, item.voltage));
    final maxCurrent =
    buckets.fold<double>(0, (max, item) => math.max(max, item.current));

    final normalizationPower =
    normalizationLimits.powerW > 0 ? normalizationLimits.powerW : maxPower;
    final normalizationVoltage =
    normalizationLimits.voltageV > 0 ? normalizationLimits.voltageV : maxVoltage;
    final normalizationCurrent =
    normalizationLimits.currentA > 0 ? normalizationLimits.currentA : maxCurrent;

    final bucketWidth = chartRect.width / buckets.length;
    final groupWidth = bucketWidth * 0.60;
    final barWidth = groupWidth / 3;

    final powerPaint = Paint()..color = _powerColor;
    final voltagePaint = Paint()..color = _voltageColor;
    final currentPaint = Paint()..color = _currentColor;

    for (int i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      final baseX = chartRect.left + (bucketWidth * i) + ((bucketWidth - groupWidth) / 2);

      final powerRatio = _normalizedRatio(bucket.power, normalizationPower);
      final voltageRatio = _normalizedRatio(bucket.voltage, normalizationVoltage);
      final currentRatio = _normalizedRatio(bucket.current, normalizationCurrent);

      _drawBar(
        canvas: canvas,
        rect: Rect.fromLTWH(
          baseX,
          chartRect.bottom - (chartRect.height * powerRatio),
          barWidth,
          chartRect.height * powerRatio,
        ),
        paint: powerPaint,
      );

      _drawBar(
        canvas: canvas,
        rect: Rect.fromLTWH(
          baseX + barWidth,
          chartRect.bottom - (chartRect.height * voltageRatio),
          barWidth,
          chartRect.height * voltageRatio,
        ),
        paint: voltagePaint,
      );

      _drawBar(
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
      if (shouldPaintLabel) {
        final tp = TextPainter(
          text: TextSpan(text: bucket.label, style: textStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(minWidth: bucketWidth, maxWidth: bucketWidth);

        tp.paint(
          canvas,
          Offset(
            chartRect.left + (bucketWidth * i),
            chartRect.bottom + 8,
          ),
        );
      }
    }
  }

  double _normalizedRatio(double value, double maxValue) {
    if (maxValue <= 0) return 0;
    final ratio = value / maxValue;
    return ratio.clamp(0.0, 1.0);
  }

  bool _shouldPaintLabel(int index, int total, AnalyticsChartMode mode) {
    switch (mode) {
      case AnalyticsChartMode.currentMoment:
        return index % 3 == 0 || index == total - 1;
      case AnalyticsChartMode.todayBands:
        return true;
      case AnalyticsChartMode.weekDays:
        return true;
      case AnalyticsChartMode.rangePeriods:
        if (total <= 6) return true;
        return index % 2 == 0 || index == total - 1;
    }
  }

  void _drawBar({
    required Canvas canvas,
    required Rect rect,
    required Paint paint,
  }) {
    if (rect.height <= 0) return;

    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(3),
    );
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GroupedHistogramPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.mode != mode ||
        oldDelegate.normalizationLimits != normalizationLimits;
  }
}

class _AggregateLinePainter extends CustomPainter {
  _AggregateLinePainter({
    required this.buckets,
    required this.textStyle,
    required this.gridColor,
    required this.mode,
  });

  final List<_GroupedBucket> buckets;
  final TextStyle textStyle;
  final Color gridColor;
  final AnalyticsChartMode mode;

  static const _lineColor = Color(0xFF2563EB);

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

    if (buckets.isEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'No hay datos para este periodo',
          style: textStyle.copyWith(fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);

      tp.paint(
        canvas,
        Offset(
          (size.width - tp.width) / 2,
          (size.height - tp.height) / 2,
        ),
      );
      return;
    }

    final values = buckets.map((e) => e.energy).toList();
    final maxValue = values.fold<double>(0, math.max);
    final minValue = values.fold<double>(double.infinity, math.min);
    final safeMinValue = minValue == double.infinity ? 0.0 : minValue;
    final valueRange = (maxValue - safeMinValue).abs() < 0.0001
        ? math.max(1.0, maxValue)
        : (maxValue - safeMinValue);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    const gridLines = 5;
    for (int i = 0; i < gridLines; i++) {
      final ratio = i / (gridLines - 1);
      final y = chartRect.bottom - (chartRect.height * ratio);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );

      final value = safeMinValue + (valueRange * ratio);
      final label = value >= 100
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2);

      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(0, y - (tp.height / 2)));
    }

    final axisPaint = Paint()
      ..color = gridColor.withOpacity(0.9)
      ..strokeWidth = 1.2;

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );

    final pointSpacing =
    buckets.length == 1 ? 0.0 : chartRect.width / (buckets.length - 1);

    final linePaint = Paint()
      ..color = _lineColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = _lineColor
      ..style = PaintingStyle.fill;

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
      canvas.drawCircle(
        point,
        5.5,
        Paint()
          ..color = _lineColor.withOpacity(0.16)
          ..style = PaintingStyle.fill,
      );
    }

    for (int i = 0; i < buckets.length; i++) {
      final shouldPaintLabel = _shouldPaintLabel(i, buckets.length, mode);
      if (!shouldPaintLabel) continue;

      final label = buckets[i].label;
      final tp = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(minWidth: 48, maxWidth: 48);

      final dx = (points[i].dx - 24).clamp(chartRect.left, chartRect.right - 48);
      tp.paint(canvas, Offset(dx, chartRect.bottom + 8));
    }
  }

  bool _shouldPaintLabel(int index, int total, AnalyticsChartMode mode) {
    switch (mode) {
      case AnalyticsChartMode.currentMoment:
        return index % 3 == 0 || index == total - 1;
      case AnalyticsChartMode.todayBands:
        return true;
      case AnalyticsChartMode.weekDays:
        return true;
      case AnalyticsChartMode.rangePeriods:
        if (total <= 6) return true;
        return index % 2 == 0 || index == total - 1;
    }
  }

  @override
  bool shouldRepaint(covariant _AggregateLinePainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.mode != mode;
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendChip(
          color: Color(0xFF2563EB),
          label: 'Potencia',
        ),
        _LegendChip(
          color: Color(0xFF7C3AED),
          label: 'Voltaje',
        ),
        _LegendChip(
          color: Color(0xFF14B8A6),
          label: 'Corriente',
        ),
      ],
    );
  }
}

class _AggregateLegendRow extends StatelessWidget {
  const _AggregateLegendRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _LegendChip(
          color: Color(0xFF2563EB),
          label: 'Consumo',
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
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
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withOpacity(0.12)
              : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? scheme.primary.withOpacity(0.55)
                : scheme.outlineVariant.withOpacity(0.6),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? scheme.primary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}