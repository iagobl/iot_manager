import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iot_manager/core/error/app_exception.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum ChartRange { today, week, month }
enum ChartMetric { consumption, power, voltage }

class DeviceChartsController extends ChangeNotifier {
  DeviceChartsController({
    required this.deviceId,
    required this.remoteDatasource,
  });

  static const Duration liveWindowDuration = Duration(minutes: 20);

  final String deviceId;
  final DevicesRemoteDatasource remoteDatasource;

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
      final result = await remoteDatasource.fetchReadingsRange(
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
    if (range == newRange) return;
    range = newRange;
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
                border: pw.Border.all(color: borderColor),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${data.title} · ${data.subtitle}',
                    style: const pw.TextStyle(
                      fontSize: 10.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.SizedBox(
                    width: double.infinity,
                    height: 250,
                    child: pw.Image(
                      chartImage,
                      fit: pw.BoxFit.fitWidth,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pdfSectionTitle('Interpretación del informe', mainColor),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: borderColor),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Bullet(text: 'Dispositivo: $deviceName.'),
                  pw.Bullet(text: 'Métrica: $metricLabel.'),
                  pw.Bullet(text: 'Período: $rangeLabel.'),
                  pw.Bullet(
                    text:
                    'Resumen: mín ${formatChartValue(data.min, data.unit)}, '
                        'máx ${formatChartValue(data.max, data.unit)}, '
                        'media ${formatChartValue(data.average, data.unit)}.',
                  ),
                  pw.Bullet(
                    text: 'Muestras utilizadas: ${data.points.length}.',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Documento generado por tfg-iot',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700,),
              ),
            ),
          ],
        ),
      );

      final filename = 'informe_${sanitize(deviceName)}_${metricLabel.toLowerCase()}_${rangeLabel.replaceAll(' ', '_').toLowerCase()}.pdf';

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: filename,
      );
    } catch (error) {
      errorMessage = ErrorMapper.mapFailure(error).message;
      debugPrint('[DeviceChartsController] exportCompleteReportPdf -> $error');
      notifyListeners();
      rethrow;
    } finally {
      exportingPdf = false;
      notifyListeners();
    }
  }

  Future<Uint8List> buildChartPngForPdf(PreparedChartData chartData) async {
    const width = 1400.0;
    const height = 520.0;

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = const Size(width, height);

      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

      final painter = AdvancedLinePainter(
        data: chartData,
        drawHeader: false,
        pdfMode: true,
        showXAxisLabels: true,
      );

      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw const DeviceAppException('No se pudo generar la imagen del gráfico para el PDF.');
      }

      return byteData.buffer.asUint8List();
    } catch (error) {
      throw ErrorMapper.mapException(error);
    }
  }

  String _buildRowsSignature(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return 'empty';

    final first = rows.first;
    final last = rows.last;

    return [
      rows.length,
      first['ts'] ?? '',
      last['ts'] ?? '',
      first['power_w'] ?? '',
      last['power_w'] ?? '',
      first['voltage_v'] ?? '',
      last['voltage_v'] ?? '',
      first['energy_wh'] ?? '',
      last['energy_wh'] ?? '',
    ].join('|');
  }

  @override
  void dispose() {
    stopSilentRefresh();
    super.dispose();
  }

  static pw.Widget pdfInfoCard({
    required String title,
    required List<List<String>> rows,
    required PdfColor borderColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold,),
          ),
          pw.SizedBox(height: 8),
          ...rows.map(
                (row) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 82,
                    child: pw.Text(
                      '${row[0]}:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      row[1],
                      style: const pw.TextStyle(fontSize: 10.5),
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

  static pw.Widget pdfSectionTitle(String title, PdfColor color) {
    return pw.Text(title,
      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: color,),
    );
  }

  static pw.Widget pdfStatBox({
    required String label,
    required String value,
    required PdfColor borderColor,
  }) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor),
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class PreparedChartData {
  const PreparedChartData({
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.points,
    required this.total,
    required this.average,
    required this.min,
    required this.max,
    required this.axisStart,
    required this.axisEnd,
    required this.range,
    required this.latestValue,
    required this.latestLabel,
  });

  final String title;
  final String subtitle;
  final String unit;
  final List<ChartPoint> points;
  final double? total;
  final double? average;
  final double? min;
  final double? max;
  final DateTime axisStart;
  final DateTime axisEnd;
  final ChartRange range;
  final double? latestValue;
  final String? latestLabel;
}

class ChartPoint {
  const ChartPoint({
    required this.x,
    required this.value,
    required this.label,
  });

  final DateTime x;
  final double value;
  final String label;
}

PreparedChartData buildChartData({
  required List<Map<String, dynamic>> rows,
  required DateTime from,
  required DateTime now,
  required ChartRange range,
  required ChartMetric metric,
}) {
  switch (metric) {
    case ChartMetric.power:
      return buildMetricData(
        rows: rows,
        range: range,
        now: now,
        extractor: (r) => toDouble(r['power_w']),
        title: 'Potencia (W)',
        unit: 'W',
      );
    case ChartMetric.voltage:
      return buildMetricData(
        rows: rows,
        range: range,
        now: now,
        extractor: (r) => toDouble(r['voltage_v']),
        title: 'Voltaje (V)',
        unit: 'V',
      );
    case ChartMetric.consumption:
      return buildConsumptionData(
        rows: rows,
        range: range,
        now: now,
      );
  }
}

PreparedChartData buildMetricData({
  required List<Map<String, dynamic>> rows,
  required ChartRange range,
  required DateTime now,
  required double? Function(Map<String, dynamic>) extractor,
  required String title,
  required String unit,
}) {
  final axis = axisBounds(range, now);
  final rawValues = <double>[];

  if (range == ChartRange.today) {
    final points = <ChartPoint>[];

    for (final row in rows) {
      final ts = DateTime.tryParse((row['ts'] ?? '').toString())?.toLocal();
      final value = extractor(row);

      if (ts == null || value == null) continue;
      if (ts.isBefore(axis.$1) || ts.isAfter(axis.$2)) continue;

      rawValues.add(value);
      points.add(ChartPoint(x: ts, value: value, label: xLabelForRange(ts, range)));
    }

    return PreparedChartData(
      title: title,
      subtitle: subtitleForRange(range),
      unit: unit,
      points: points,
      total: rawValues.isEmpty ? null : rawValues.reduce((a, b) => a + b),
      average: rawValues.isEmpty ? null : rawValues.reduce((a, b) => a + b) / rawValues.length,
      min: rawValues.isEmpty ? null : rawValues.reduce(math.min),
      max: rawValues.isEmpty ? null : rawValues.reduce(math.max),
      axisStart: axis.$1,
      axisEnd: axis.$2,
      range: range,
      latestValue: points.isEmpty ? null : points.last.value,
      latestLabel: points.isEmpty ? null : points.last.label,
    );
  }

  final Map<DateTime, List<double>> buckets = {};

  for (final row in rows) {
    final ts = DateTime.tryParse((row['ts'] ?? '').toString())?.toLocal();
    final value = extractor(row);

    if (ts == null || value == null) continue;
    if (ts.isBefore(axis.$1) || ts.isAfter(axis.$2)) continue;

    rawValues.add(value);

    final bucket = bucketDate(ts, range);
    buckets.putIfAbsent(bucket, () => []).add(value);
  }

  final sortedKeys = buckets.keys.toList()..sort();

  final points = sortedKeys.map((key) {
    final values = buckets[key]!;
    final avg = values.reduce((a, b) => a + b) / values.length;

    return ChartPoint(
      x: key,
      value: avg,
      label: xLabelForRange(key, range),
    );
  }).toList();

  return PreparedChartData(
    title: title,
    subtitle: subtitleForRange(range),
    unit: unit,
    points: points,
    total: rawValues.isEmpty ? null : rawValues.reduce((a, b) => a + b),
    average: rawValues.isEmpty ? null : rawValues.reduce((a, b) => a + b) / rawValues.length,
    min: rawValues.isEmpty ? null : rawValues.reduce(math.min),
    max: rawValues.isEmpty ? null : rawValues.reduce(math.max),
    axisStart: axis.$1,
    axisEnd: axis.$2,
    range: range,
    latestValue: points.isEmpty ? null : points.last.value,
    latestLabel: points.isEmpty ? null : points.last.label,
  );
}

PreparedChartData buildConsumptionData({
  required List<Map<String, dynamic>> rows,
  required ChartRange range,
  required DateTime now,
}) {
  final axis = axisBounds(range, now);
  final rawValues = <double>[];

  if (range == ChartRange.today) {
    final points = <ChartPoint>[];

    for (final row in rows) {
      final ts = DateTime.tryParse((row['ts'] ?? '').toString())?.toLocal();
      final value = toDouble(row['energy_wh']);

      if (ts == null || value == null) continue;
      if (ts.isBefore(axis.$1) || ts.isAfter(axis.$2)) continue;

      rawValues.add(value);
      points.add(
        ChartPoint(
          x: ts,
          value: value,
          label: xLabelForRange(ts, range),
        ),
      );
    }

    return PreparedChartData(
      title: 'Consumo (Wh)',
      subtitle: subtitleForRange(range),
      unit: 'Wh',
      points: points,
      total: rawValues.isEmpty ? null : rawValues.reduce((a, b) => a + b),
      average: rawValues.isEmpty
          ? null
          : rawValues.reduce((a, b) => a + b) / rawValues.length,
      min: rawValues.isEmpty ? null : rawValues.reduce(math.min),
      max: rawValues.isEmpty ? null : rawValues.reduce(math.max),
      axisStart: axis.$1,
      axisEnd: axis.$2,
      range: range,
      latestValue: points.isEmpty ? null : points.last.value,
      latestLabel: points.isEmpty ? null : points.last.label,
    );
  }

  final Map<DateTime, double> buckets = {};

  for (final row in rows) {
    final ts = DateTime.tryParse((row['ts'] ?? '').toString())?.toLocal();
    final value = toDouble(row['energy_wh']);

    if (ts == null || value == null) continue;
    if (ts.isBefore(axis.$1) || ts.isAfter(axis.$2)) continue;

    rawValues.add(value);

    final bucket = bucketDate(ts, range);
    buckets[bucket] = (buckets[bucket] ?? 0) + value;
  }

  final sortedKeys = buckets.keys.toList()..sort();

  final points = sortedKeys.map((key) => ChartPoint(
      x: key,
      value: buckets[key]!,
      label: xLabelForRange(key, range),
    ),
  ).toList();

  return PreparedChartData(
    title: 'Consumo (Wh)',
    subtitle: subtitleForRange(range),
    unit: 'Wh',
    points: points,
    total: rawValues.isEmpty ? null : rawValues.reduce((a, b) => a + b),
    average: rawValues.isEmpty ? null : rawValues.reduce((a, b) => a + b) / rawValues.length,
    min: rawValues.isEmpty ? null : rawValues.reduce(math.min),
    max: rawValues.isEmpty ? null : rawValues.reduce(math.max),
    axisStart: axis.$1,
    axisEnd: axis.$2,
    range: range,
    latestValue: points.isEmpty ? null : points.last.value,
    latestLabel: points.isEmpty ? null : points.last.label,
  );
}

(DateTime, DateTime) axisBounds(ChartRange range, DateTime end) {
  switch (range) {
    case ChartRange.today:
      return (end.subtract(DeviceChartsController.liveWindowDuration), end);
    case ChartRange.week:
      return (end.subtract(const Duration(days: 6)), end);
    case ChartRange.month:
      return (end.subtract(const Duration(days: 29)), end);
  }
}

DateTime bucketDate(DateTime ts, ChartRange range) {
  switch (range) {
    case ChartRange.today:
      return DateTime(ts.year, ts.month, ts.day, ts.hour, ts.minute);
    case ChartRange.week:
    case ChartRange.month:
      return DateTime(ts.year, ts.month, ts.day);
  }
}

String subtitleForRange(ChartRange range) {
  switch (range) {
    case ChartRange.today:
      return 'Seguimiento en tiempo real';
    case ChartRange.week:
      return 'Agrupado por días (últimos 7 días)';
    case ChartRange.month:
      return 'Agrupado por días (últimos 30 días)';
  }
}

String xLabelForRange(DateTime date, ChartRange range) {
  switch (range) {
    case ChartRange.today:
      return '${two(date.hour)}:${two(date.minute)}';
    case ChartRange.week:
    case ChartRange.month:
      return '${two(date.day)}/${two(date.month)}';
  }
}

double? toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.'));
}

String formatChartValue(double? value, String unit) {
  if (value == null) return '--';
  if (value.abs() >= 100) return '${value.toStringAsFixed(0)} $unit';
  if (value.abs() >= 10) return '${value.toStringAsFixed(1)} $unit';
  return '${value.toStringAsFixed(2)} $unit';
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
      return '7 días';
    case ChartRange.month:
      return '30 días';
  }
}

String formatReportRange(DateTime start, DateTime end) {
  return '${formatDateTime(start)} - ${formatDateTime(end)}';
}

String formatDateTime(DateTime dt) {
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

String sanitize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_\-]'), '');
}

String two(int value) => value.toString().padLeft(2, '0');

class AdvancedLinePainter extends CustomPainter {
  AdvancedLinePainter({
    required this.data,
    this.drawHeader = true,
    this.pdfMode = false,
    this.showXAxisLabels = true,
  });

  final PreparedChartData data;
  final bool drawHeader;
  final bool pdfMode;
  final bool showXAxisLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final leftPad = pdfMode ? 78.0 : 52.0;
    final rightPad = pdfMode ? 24.0 : 18.0;
    final topPad = drawHeader ? (pdfMode ? 72.0 : 22.0) : (pdfMode ? 18.0 : 10.0);
    final bottomPad = pdfMode ? 66.0 : (showXAxisLabels ? 34.0 : 14.0);

    final chartRect = Rect.fromLTRB(
      leftPad,
      topPad,
      size.width - rightPad,
      size.height - bottomPad,
    );

    if (chartRect.width <= 0 || chartRect.height <= 0 || data.points.isEmpty) {
      return;
    }

    final axisStartMs = data.axisStart.millisecondsSinceEpoch.toDouble();
    final axisEndMs = data.axisEnd.millisecondsSinceEpoch.toDouble();
    final axisRangeMs = math.max(1.0, axisEndMs - axisStartMs);

    var minY = data.min ?? 0;
    var maxY = data.max ?? 0;

    if ((maxY - minY).abs() < 0.0001) {
      minY -= 1;
      maxY += 1;
    } else {
      final pad = (maxY - minY) * 0.14;
      minY -= pad;
      maxY += pad;
    }

    final yRange = math.max(1.0, maxY - minY);

    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const horizontalLines = 6;
    for (int i = 0; i <= horizontalLines; i++) {
      final y = chartRect.top + (chartRect.height * i / horizontalLines);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final xTicks = buildXAxisTicks();
    for (final tick in xTicks) {
      final x = xForDate(tick, chartRect, axisStartMs, axisRangeMs);
      canvas.drawLine(
        Offset(x, chartRect.top),
        Offset(x, chartRect.bottom),
        gridPaint,
      );
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

    if (data.points.length == 1) {
      final only = data.points.first;
      final x = xForDate(only.x, chartRect, axisStartMs, axisRangeMs);
      final y = yForValue(only.value, chartRect, minY, yRange);

      canvas.drawCircle(Offset(x, y), 3, Paint()..color = Colors.blue.withValues(alpha: 0.92));

    } else {
      final path = Path();
      final fillPath = Path();

      for (int i = 0; i < data.points.length; i++) {
        final point = data.points[i];
        final x = xForDate(point.x, chartRect, axisStartMs, axisRangeMs);
        final y = yForValue(point.value, chartRect, minY, yRange);

        if (i == 0) {
          path.moveTo(x, y);
          fillPath.moveTo(x, chartRect.bottom);
          fillPath.lineTo(x, y);
        } else {
          path.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
      }

      final lastPoint = data.points.last;
      final lastX = xForDate(lastPoint.x, chartRect, axisStartMs, axisRangeMs);
      fillPath.lineTo(lastX, chartRect.bottom);
      fillPath.close();

      final fillPaint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;

      final linePaint = Paint()
        ..color = Colors.blue.withValues(alpha: 0.92)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);

      final lp = data.points.last;
      final lx = xForDate(lp.x, chartRect, axisStartMs, axisRangeMs);
      final ly = yForValue(lp.value, chartRect, minY, yRange);

      canvas.drawCircle(Offset(lx, ly), 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(lx, ly), 4.5,
        Paint()
          ..color = Colors.blue.withValues(alpha: 0.96)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    if (drawHeader) {
      drawTitle(canvas, size);
    }

    drawYLabels(canvas, chartRect, minY, maxY);

    if (showXAxisLabels) {
      drawXLabels(canvas, chartRect, xTicks, axisStartMs, axisRangeMs);
    }
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

  List<DateTime> buildXAxisTicks() {
    switch (data.range) {
      case ChartRange.today:
        return List.generate(5, (i) {
          final ratio = i / 4;
          final millis = data.axisStart.millisecondsSinceEpoch +
              ((data.axisEnd.millisecondsSinceEpoch -
                  data.axisStart.millisecondsSinceEpoch) *
                  ratio)
                  .round();
          return DateTime.fromMillisecondsSinceEpoch(millis);
        });
      case ChartRange.week:
        return [
          data.axisStart,
          data.axisStart.add(const Duration(days: 2)),
          data.axisStart.add(const Duration(days: 4)),
          data.axisEnd,
        ];
      case ChartRange.month:
        return List.generate(5, (i) {
          final ratio = i / 4;
          final millis = data.axisStart.millisecondsSinceEpoch +
              ((data.axisEnd.millisecondsSinceEpoch -
                  data.axisStart.millisecondsSinceEpoch) *
                  ratio)
                  .round();
          final d = DateTime.fromMillisecondsSinceEpoch(millis);
          return DateTime(d.year, d.month, d.day);
        });
    }
  }

  String tickLabel(DateTime tick) {
    switch (data.range) {
      case ChartRange.today:
        return '${two(tick.hour)}:${two(tick.minute)}';
      case ChartRange.week:
      case ChartRange.month:
        return '${tick.day.toString().padLeft(2, '0')}/${tick.month.toString().padLeft(2, '0')}';
    }
  }

  void drawTitle(Canvas canvas, Size size) {
    final title = TextPainter(
      text: TextSpan(
        text: data.title,
        style: TextStyle(
          fontSize: pdfMode ? 24 : 15,
          fontWeight: FontWeight.w800,
          color: Colors.black,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.width - 24);

    title.paint(canvas, const Offset(0, 0));

    final subtitle = TextPainter(
      text: TextSpan(
        text: data.subtitle,
        style: TextStyle(
          fontSize: pdfMode ? 18 : 12,
          color: Colors.black.withValues(alpha: 0.65),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: size.width - 24);

    subtitle.paint(canvas, Offset(0, title.height + 6));
  }

  void drawYLabels(Canvas canvas, Rect chartRect, double minY, double maxY) {
    const steps = 6;

    for (int i = 0; i <= steps; i++) {
      final value = maxY - ((maxY - minY) * i / steps);
      final y = chartRect.top + (chartRect.height * i / steps);

      final tp = TextPainter(
        text: TextSpan(
          text: compactNumber(value),
          style: TextStyle(
            color: Colors.black87,
            fontSize: pdfMode ? 18 : 10,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: chartRect.left - 8);

      tp.paint(canvas, Offset(chartRect.left - tp.width - 10, y - tp.height / 2));
    }
  }

  void drawXLabels(
      Canvas canvas,
      Rect chartRect,
      List<DateTime> ticks,
      double axisStartMs,
      double axisRangeMs,
      ) {
    for (final tick in ticks) {
      final x = xForDate(tick, chartRect, axisStartMs, axisRangeMs);

      final tp = TextPainter(
        text: TextSpan(
          text: tickLabel(tick),
          style: TextStyle(
            color: Colors.black87,
            fontSize: pdfMode ? 18 : 10,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: pdfMode ? 90 : 54);

      var dx = x - tp.width / 2;

      if (dx < chartRect.left) dx = chartRect.left;
      if (dx + tp.width > chartRect.right) {
        dx = chartRect.right - tp.width;
      }

      tp.paint(canvas, Offset(dx, chartRect.bottom + (pdfMode ? 12 : 8)));
    }
  }

  String compactNumber(double value) {
    if (value.abs() >= 100) return value.toStringAsFixed(0);
    if (value.abs() >= 10) return value.toStringAsFixed(1);
    return value.toStringAsFixed(2);
  }

  @override
  bool shouldRepaint(covariant AdvancedLinePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.drawHeader != drawHeader ||
        oldDelegate.pdfMode != pdfMode ||
        oldDelegate.showXAxisLabels != showXAxisLabels;
  }
}