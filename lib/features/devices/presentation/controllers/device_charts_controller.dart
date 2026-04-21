import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/data/repositories/devices_repository_impl.dart';
import 'package:iot_manager/features/devices/domain/usecases/fetch_readings_range.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum ChartRange { today, week, month }
enum ChartMetric { consumption, power, voltage }

class DeviceChartsController extends ChangeNotifier {
  DeviceChartsController({
    required this.deviceId,
    required DevicesRemoteDatasource remoteDatasource,
  }) : fetchReadingsRange = FetchReadingsRange(
    DevicesRepositoryImpl(remoteDatasource),
  );

  static const Duration liveWindowDuration = Duration(minutes: 20);

  final String deviceId;
  final FetchReadingsRange fetchReadingsRange;

  ChartRange range = ChartRange.today;
  ChartMetric metric = ChartMetric.voltage;

  bool loading = false;
  bool refreshing = false;
  bool exportingPdf = false;
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

  Future<void> exportCompleteReportPdf({
    required String deviceName,
    required String deviceHost,
  }) async {
    if (exportingPdf) return;

    try {
      exportingPdf = true;
      errorMessage = null;
      notifyListeners();

      final data = chartData;
      final pngBytes = await buildChartPngForPdf(data);
      final chartImage = pw.MemoryImage(pngBytes);

      final pdf = pw.Document();
      final generatedAt = DateTime.now();
      final metricLabel = chartMetricLabel(metric);
      final rangeLabel = chartRangeLabel(range);
      final rangeText = formatReportRange(data.axisStart, data.axisEnd);

      final mainColor = const PdfColor.fromInt(0xFF2563EB);
      final softColor = const PdfColor.fromInt(0xFFF8FAFC);
      final borderColor = const PdfColor.fromInt(0xFFE2E8F0);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(18),
              decoration: pw.BoxDecoration(
                color: softColor,
                borderRadius: pw.BorderRadius.circular(16),
                border: pw.Border.all(color: borderColor),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Informe del dispositivo',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: mainColor,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text('Resumen de datos energéticos generado desde la pantalla de gráficas.',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pdfInfoCard(
                    title: 'Información del dispositivo',
                    rows: [
                      ['Nombre', deviceName],
                      ['IP / Host', deviceHost],
                      ['ID', deviceId],
                    ],
                    borderColor: borderColor,
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pdfInfoCard(
                    title: 'Parámetros del informe',
                    rows: [
                      ['Métrica', metricLabel],
                      ['Período', rangeLabel],
                      ['Rango temporal', rangeText],
                      ['Generado', formatDateTime(generatedAt)],
                    ],
                    borderColor: borderColor,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pdfSectionTitle('Resumen estadístico', mainColor),
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                pdfStatBox(
                  label: range == ChartRange.today ? 'Último valor' : 'Media',
                  value: formatChartValue(
                    range == ChartRange.today ? data.latestValue : data.average,
                    data.unit,
                  ),
                  borderColor: borderColor,
                ),
                pdfStatBox(
                  label: 'Mínimo',
                  value: formatChartValue(data.min, data.unit),
                  borderColor: borderColor,
                ),
                pdfStatBox(
                  label: 'Máximo',
                  value: formatChartValue(data.max, data.unit),
                  borderColor: borderColor,
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pdfSectionTitle('Gráfica', mainColor),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(14),
                border: pw.Border.all(color: borderColor),
              ),
              child: pw.Image(chartImage, fit: pw.BoxFit.contain),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (error) {
      errorMessage = ErrorMapper.mapFailure(error).message;
      rethrow;
    } finally {
      exportingPdf = false;
      notifyListeners();
    }
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
  final max = values.reduce(math.max);
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

String formatChartValue(double value, String unit) {
  if (value == value.roundToDouble()) {
    return '${value.toStringAsFixed(0)} $unit';
  }
  return '${value.toStringAsFixed(2)} $unit';
}

String formatDateTime(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

String formatReportRange(DateTime from, DateTime to) {
  return '${formatDateTime(from)} - ${formatDateTime(to)}';
}

pw.Widget pdfSectionTitle(String title, PdfColor color) {
  return pw.Text(
    title,
    style: pw.TextStyle(
      fontSize: 15,
      fontWeight: pw.FontWeight.bold,
      color: color,
    ),
  );
}

pw.Widget pdfInfoCard({
  required String title,
  required List<List<String>> rows,
  required PdfColor borderColor,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(14),
      border: pw.Border.all(color: borderColor),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        ...rows.map(
              (row) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 88,
                  child: pw.Text(
                    row[0],
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    row[1],
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget pdfStatBox({
  required String label,
  required String value,
  required PdfColor borderColor,
}) {
  return pw.Container(
    width: 160,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(12),
      border: pw.Border.all(color: borderColor),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Future<Uint8List> buildChartPngForPdf(PreparedChartData data) async {
  const width = 1200;
  const height = 620;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(width.toDouble(), height.toDouble());

  final painter = _PdfChartPainter(data);
  painter.paint(canvas, size);

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  if (bytes == null) {
    throw const ValidationAppException(
      'No se pudo generar la imagen de la gráfica.',
    );
  }

  return bytes.buffer.asUint8List();
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

class _PdfChartPainter {
  const _PdfChartPainter(this.data);

  final PreparedChartData data;

  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final chartRect = Rect.fromLTWH(80, 24, size.width - 120, size.height - 84);

    final axisPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1;

    final labelStyle = const TextStyle(
      color: Color(0xFF475569),
      fontSize: 15,
    );

    for (final y in data.yLabels) {
      final yPos = _mapY(y, chartRect);
      canvas.drawLine(
        Offset(chartRect.left, yPos),
        Offset(chartRect.right, yPos),
        axisPaint,
      );

      _paintText(
        canvas,
        formatCompact(y),
        Offset(8, yPos - 10),
        labelStyle,
        maxWidth: 60,
      );
    }

    for (final x in data.xLabels) {
      final xPos = _mapX(x, chartRect);
      canvas.drawLine(
        Offset(xPos, chartRect.top),
        Offset(xPos, chartRect.bottom),
        axisPaint,
      );

      _paintText(
        canvas,
        formatXAxisLabel(x, data.axisStart, data.axisEnd),
        Offset(xPos - 28, chartRect.bottom + 12),
        labelStyle,
        maxWidth: 70,
      );
    }

    canvas.drawRect(
      chartRect,
      Paint()
        ..color = const Color(0x00000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = const Color(0xFF94A3B8),
    );

    if (data.points.isEmpty) {
      _paintText(
        canvas,
        'Sin datos',
        Offset(chartRect.left + chartRect.width / 2 - 30, chartRect.center.dy - 10),
        const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 18,
        ),
        maxWidth: 80,
      );
      return;
    }

    final path = Path();
    for (var i = 0; i < data.points.length; i++) {
      final point = data.points[i];
      final dx = _mapX(point.time, chartRect);
      final dy = _mapY(point.value, chartRect);

      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()..color = const Color(0xFF2563EB);
    for (final point in data.points) {
      final dx = _mapX(point.time, chartRect);
      final dy = _mapY(point.value, chartRect);
      canvas.drawCircle(Offset(dx, dy), 3.5, pointPaint);
    }
  }

  double _mapX(DateTime value, Rect rect) {
    final total = data.axisEnd.difference(data.axisStart).inMilliseconds;
    if (total <= 0) return rect.left;

    final offset = value.difference(data.axisStart).inMilliseconds;
    final ratio = (offset / total).clamp(0.0, 1.0);
    return rect.left + (rect.width * ratio);
  }

  double _mapY(double value, Rect rect) {
    final min = data.yLabels.first;
    final max = data.yLabels.last;
    final span = (max - min).abs() < 0.0001 ? 1 : (max - min);
    final ratio = ((value - min) / span).clamp(0.0, 1.0);
    return rect.bottom - (rect.height * ratio);
  }

  String formatCompact(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }

  String formatXAxisLabel(DateTime value, DateTime from, DateTime to) {
    final totalDays = to.difference(from).inDays;

    if (totalDays <= 1) {
      return '${value.hour.toString().padLeft(2, '0')}:'
          '${value.minute.toString().padLeft(2, '0')}';
    }

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}';
  }

  void _paintText(
      Canvas canvas,
      String text,
      Offset offset,
      TextStyle style, {
        double maxWidth = 120,
      }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    painter.paint(canvas, offset);
  }
}
