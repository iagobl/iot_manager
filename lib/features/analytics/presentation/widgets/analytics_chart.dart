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
  });

  final AnalyticsSeries series;
  final DateTimeRange range;
  final AnalyticsChartMode mode;
  final bool showTodayModeSelector;
  final ValueChanged<AnalyticsChartMode> onModeChanged;

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
            _titleForMode(mode),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _descriptionForMode(mode),
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
          const _LegendRow(),
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
                painter: _GroupedHistogramPainter(
                  buckets: buckets,
                  textStyle:
                  Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ) ??
                      const TextStyle(fontSize: 11),
                  gridColor: scheme.outlineVariant.withOpacity(0.34),
                  mode: mode,
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
        return 'Seguimiento de las últimas 4 horas en intervalos de 15 minutos.';
      case AnalyticsChartMode.weekDays:
        return 'Media diaria de la semana actual.';
      case AnalyticsChartMode.rangePeriods:
        return 'Media por periodos temporales del rango seleccionado.';
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
    final counts = List<int>.filled(6, 0);

    for (final point in points) {
      final local = point.timestamp.toLocal();
      final bucket = local.hour ~/ 4;
      powerSums[bucket] += point.powerW;
      voltageSums[bucket] += point.voltageV;
      currentSums[bucket] += point.currentA;
      counts[bucket] += 1;
    }

    return List.generate(6, (index) {
      final count = counts[index];
      return _GroupedBucket(
        label: labels[index],
        power: count == 0 ? 0.0 : powerSums[index] / count,
        voltage: count == 0 ? 0.0 : voltageSums[index] / count,
        current: count == 0 ? 0.0 : currentSums[index] / count,
      );
    });
  }

  List<_GroupedBucket> _buildCurrentMoment(List<AnalyticsPoint> points) {
    final latestLocal = points.last.timestamp.toLocal();

    final alignedMinute = (latestLocal.minute ~/ 15) * 15;
    final alignedEnd = DateTime(
      latestLocal.year,
      latestLocal.month,
      latestLocal.day,
      latestLocal.hour,
      alignedMinute,
    );

    // 16 bloques de 15 minutos = 4 horas exactas
    final start = alignedEnd.subtract(const Duration(hours: 3, minutes: 45));

    final powerSums = List<double>.filled(16, 0.0);
    final voltageSums = List<double>.filled(16, 0.0);
    final currentSums = List<double>.filled(16, 0.0);
    final counts = List<int>.filled(16, 0);

    for (final point in points) {
      final local = point.timestamp.toLocal();

      if (local.isBefore(start) ||
          local.isAfter(alignedEnd.add(const Duration(minutes: 14, seconds: 59)))) {
        continue;
      }

      final diffMinutes = local.difference(start).inMinutes;
      final bucket = diffMinutes ~/ 15;

      if (bucket >= 0 && bucket < 16) {
        powerSums[bucket] += point.powerW;
        voltageSums[bucket] += point.voltageV;
        currentSums[bucket] += point.currentA;
        counts[bucket] += 1;
      }
    }

    return List.generate(16, (index) {
      final slotTime = start.add(Duration(minutes: index * 15));
      final label =
          '${slotTime.hour.toString().padLeft(2, '0')}:${slotTime.minute.toString().padLeft(2, '0')}';
      final count = counts[index];

      return _GroupedBucket(
        label: label,
        power: count == 0 ? 0.0 : powerSums[index] / count,
        voltage: count == 0 ? 0.0 : voltageSums[index] / count,
        current: count == 0 ? 0.0 : currentSums[index] / count,
      );
    });
  }

  List<_GroupedBucket> _buildWeekDays(List<AnalyticsPoint> points) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    final powerSums = List<double>.filled(7, 0.0);
    final voltageSums = List<double>.filled(7, 0.0);
    final currentSums = List<double>.filled(7, 0.0);
    final counts = List<int>.filled(7, 0);

    for (final point in points) {
      final local = point.timestamp.toLocal();
      final bucket = local.weekday - 1;
      powerSums[bucket] += point.powerW;
      voltageSums[bucket] += point.voltageV;
      currentSums[bucket] += point.currentA;
      counts[bucket] += 1;
    }

    return List.generate(7, (index) {
      final count = counts[index];
      return _GroupedBucket(
        label: labels[index],
        power: count == 0 ? 0.0 : powerSums[index] / count,
        voltage: count == 0 ? 0.0 : voltageSums[index] / count,
        current: count == 0 ? 0.0 : currentSums[index] / count,
      );
    });
  }

  List<_GroupedBucket> _buildRangePeriods(
      List<AnalyticsPoint> points,
      DateTimeRange range,
      ) {
    final totalDays = range.end.difference(range.start).inDays + 1;

    if (totalDays <= 10) {
      final dayBuckets = <DateTime, List<AnalyticsPoint>>{};
      for (final point in points) {
        final local = point.timestamp.toLocal();
        final day = DateTime(local.year, local.month, local.day);
        dayBuckets.putIfAbsent(day, () => <AnalyticsPoint>[]).add(point);
      }

      final orderedDays = dayBuckets.keys.toList()..sort();
      return orderedDays.map((day) {
        final entries = dayBuckets[day]!;
        return _GroupedBucket(
          label:
          '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}',
          power: _avg(entries.map((e) => e.powerW)),
          voltage: _avg(entries.map((e) => e.voltageV)),
          current: _avg(entries.map((e) => e.currentA)),
        );
      }).toList();
    }

    final periodSize = totalDays <= 31 ? 7 : (totalDays / 4).ceil();
    final buckets = <_GroupedBucket>[];

    var periodStart = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );

    while (!periodStart.isAfter(range.end)) {
      final tentativeEnd = periodStart.add(Duration(days: periodSize - 1));
      final periodEnd = tentativeEnd.isAfter(range.end) ? range.end : tentativeEnd;

      final entries = points.where((point) {
        final local = point.timestamp.toLocal();
        return !local.isBefore(periodStart) &&
            !local.isAfter(
              DateTime(
                periodEnd.year,
                periodEnd.month,
                periodEnd.day,
                23,
                59,
                59,
              ),
            );
      }).toList();

      buckets.add(
        _GroupedBucket(
          label:
          '${periodStart.day.toString().padLeft(2, '0')}-${periodEnd.day.toString().padLeft(2, '0')}',
          power: _avg(entries.map((e) => e.powerW)),
          voltage: _avg(entries.map((e) => e.voltageV)),
          current: _avg(entries.map((e) => e.currentA)),
        ),
      );

      periodStart = DateTime(
        periodEnd.year,
        periodEnd.month,
        periodEnd.day,
      ).add(const Duration(days: 1));
    }

    return buckets;
  }

  double _avg(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0.0;
    final sum = list.fold<double>(0.0, (acc, item) => acc + item);
    return sum / list.length;
  }
}

class _GroupedBucket {
  const _GroupedBucket({
    required this.label,
    required this.power,
    required this.voltage,
    required this.current,
  });

  final String label;
  final double power;
  final double voltage;
  final double current;
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

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: scheme.primary.withOpacity(0.12),
      side: BorderSide(
        color: selected
            ? scheme.primary.withOpacity(0.30)
            : scheme.outlineVariant.withOpacity(0.70),
      ),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: const [
        _LegendItem(color: Color(0xFF2563EB), label: 'Potencia'),
        _LegendItem(color: Color(0xFF8B5CF6), label: 'Voltaje'),
        _LegendItem(color: Color(0xFF14B8A6), label: 'Corriente'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: style),
      ],
    );
  }
}

class _GroupedHistogramPainter extends CustomPainter {
  _GroupedHistogramPainter({
    required this.buckets,
    required this.textStyle,
    required this.gridColor,
    required this.mode,
  });

  final List<_GroupedBucket> buckets;
  final TextStyle textStyle;
  final Color gridColor;
  final AnalyticsChartMode mode;

  static const Color _powerColor = Color(0xFF2563EB);
  static const Color _voltageColor = Color(0xFF8B5CF6);
  static const Color _currentColor = Color(0xFF14B8A6);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 52.0;
    const right = 16.0;
    const top = 18.0;
    const bottom = 42.0;

    final chart = Rect.fromLTWH(
      left,
      top,
      size.width - left - right,
      size.height - top - bottom,
    );

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = chart.top + (chart.height / 4) * i;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    if (buckets.isEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'Sin datos disponibles para este rango',
          style: textStyle.copyWith(fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: chart.width);

      tp.paint(
        canvas,
        Offset(
          chart.left + (chart.width - tp.width) / 2,
          chart.top + (chart.height - tp.height) / 2,
        ),
      );
      return;
    }

    final maxPower = buckets.fold<double>(
      0.0,
          (prev, item) => math.max(prev, item.power).toDouble(),
    );
    final maxVoltage = buckets.fold<double>(
      0.0,
          (prev, item) => math.max(prev, item.voltage).toDouble(),
    );
    final maxCurrent = buckets.fold<double>(
      0.0,
          (prev, item) => math.max(prev, item.current).toDouble(),
    );

    double normalize(double value, double max) {
      if (max <= 0) return 0.0;
      return (value / max) * 100.0;
    }

    final compact = mode == AnalyticsChartMode.currentMoment;
    final groupSpace = chart.width / buckets.length;
    final groupWidth = compact
        ? math.min(groupSpace * 0.78, 16.0).toDouble()
        : math.min(groupSpace * 0.72, 42.0).toDouble();

    final singleBarWidth = (groupWidth / 3).clamp(
      compact ? 1.6 : 6.0,
      compact ? 3.8 : 14.0,
    ).toDouble();

    final barGap = compact ? 0.6 : 2.0;

    for (var i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      final centerX = chart.left + groupSpace * i + groupSpace / 2;
      final startX = centerX - (groupWidth / 2);

      final powerPercent = normalize(bucket.power, maxPower);
      final voltagePercent = normalize(bucket.voltage, maxVoltage);
      final currentPercent = normalize(bucket.current, maxCurrent);

      _drawBar(
        canvas: canvas,
        chart: chart,
        x: startX,
        width: singleBarWidth,
        percent: powerPercent,
        color: _powerColor,
      );

      _drawBar(
        canvas: canvas,
        chart: chart,
        x: startX + singleBarWidth + barGap,
        width: singleBarWidth,
        percent: voltagePercent,
        color: _voltageColor,
      );

      _drawBar(
        canvas: canvas,
        chart: chart,
        x: startX + (singleBarWidth + barGap) * 2,
        width: singleBarWidth,
        percent: currentPercent,
        color: _currentColor,
      );

      final shouldPaintLabel = compact ? i % 4 == 0 : true;
      if (shouldPaintLabel) {
        final labelPainter = TextPainter(
          text: TextSpan(text: bucket.label, style: textStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(minWidth: 0, maxWidth: 42);

        labelPainter.paint(
          canvas,
          Offset(centerX - labelPainter.width / 2, chart.bottom + 8),
        );
      }
    }

    const axisValues = [100, 75, 50, 25, 0];
    for (var i = 0; i < axisValues.length; i++) {
      final y = chart.top + (chart.height / 4) * i;
      final valuePainter = TextPainter(
        text: TextSpan(
          text: '${axisValues[i]}%',
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 8);

      valuePainter.paint(canvas, Offset(0, y - valuePainter.height / 2));
    }
  }

  void _drawBar({
    required Canvas canvas,
    required Rect chart,
    required double x,
    required double width,
    required double percent,
    required Color color,
  }) {
    final normalized = (percent / 100).clamp(0.0, 1.0);
    final barHeight = normalized * chart.height;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        x,
        chart.bottom - barHeight,
        width,
        barHeight,
      ),
      const Radius.circular(4),
    );

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color,
          color.withOpacity(0.68),
        ],
      ).createShader(chart);

    final borderPaint = Paint()
      ..color = color.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(rect, fillPaint);
    canvas.drawRRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _GroupedHistogramPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.mode != mode;
  }
}