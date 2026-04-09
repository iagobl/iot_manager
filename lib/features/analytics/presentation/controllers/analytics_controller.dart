import 'package:flutter/material.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/analytics/data/datasources/analytics_remote_datasource.dart';
import 'package:iot_manager/features/analytics/data/repositories/analytics_repository_impl.dart';
import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AnalyticsController extends ChangeNotifier {
  AnalyticsController() : repository = AnalyticsRepositoryImpl(AnalyticsRemoteDatasource());

  final AnalyticsRepositoryImpl repository;

  bool loading = false;
  bool exporting = false;
  String? errorMessage;

  List<AnalyticsScopeOption> scopes = const [];
  AnalyticsScopeOption? selectedScope;
  AnalyticsRangePreset selectedPreset = AnalyticsRangePreset.today;
  DateTimeRange? customRange;

  List<AnalyticsSample> samples = const [];
  List<AnalyticsBreakdownItem> breakdown = const [];

  Future<void> init() async {
    loading = true;
    errorMessage = null;
    notifyListeners();

    try {
      scopes = await repository.getAvailableScopes();
      selectedScope = scopes.isNotEmpty ? scopes.first : null;
      await loadData();
    } catch (error) {
      errorMessage = ErrorMapper.mapFailure(error).message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  DateTimeRange get activeRange {
    final now = DateTime.now();

    switch (selectedPreset) {
      case AnalyticsRangePreset.today:
        final start = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: start, end: now);

      case AnalyticsRangePreset.last7Days:
        final weekday = now.weekday;
        final monday = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: weekday - 1));
        return DateTimeRange(start: monday, end: now,);

      case AnalyticsRangePreset.last30Days:
        final firstDayOfMonth = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: firstDayOfMonth, end: now);

      case AnalyticsRangePreset.custom:
        return customRange ??
            DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
    }
  }

  AnalyticsSeries get series => AnalyticsSeries.fromSamples(samples);

  bool get hasData => samples.isNotEmpty;

  double get currentPowerW => samples.isNotEmpty ? samples.last.powerW : 0.0;
  double get currentVoltageV => samples.isNotEmpty ? samples.last.voltageV : 0.0;
  double get currentCurrentA => samples.isNotEmpty ? samples.last.currentA : 0.0;
  bool get isCurrentlyOn => currentPowerW > 0.5;
  double get rangeConsumptionWh => calculateRangeConsumptionWh(samples);

  Future<void> reload() => loadData(notify: true);

  Future<void> selectScope(AnalyticsScopeOption option) async {
    selectedScope = option;
    notifyListeners();
    await loadData(notify: true);
  }

  Future<void> selectPreset(AnalyticsRangePreset preset) async {
    selectedPreset = preset;
    notifyListeners();
    await loadData(notify: true);
  }

  Future<void> selectCustomRange(DateTimeRange range) async {
    customRange = range;
    selectedPreset = AnalyticsRangePreset.custom;
    notifyListeners();
    await loadData(notify: true);
  }

  Future<void> loadData({bool notify = false}) async {
    final scope = selectedScope;
    if (scope == null) return;

    if (notify) {
      loading = true;
      errorMessage = null;
      notifyListeners();
    }

    try {
      final query = AnalyticsQuery(
        scope: scope,
        from: activeRange.start,
        to: activeRange.end,
      );

      samples = await repository.getSamples(query);
      breakdown = await repository.getBreakdown(query);
      errorMessage = null;
    } catch (error) {
      errorMessage = ErrorMapper.mapFailure(error).message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  double calculateRangeConsumptionWh(List<AnalyticsSample> input) {
    if (input.isEmpty) return 0.0;

    final byDevice = <String, List<AnalyticsSample>>{};
    for (final sample in input) {
      final key = sample.deviceName;
      byDevice.putIfAbsent(key, () => <AnalyticsSample>[]).add(sample);
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

  String formatNumber(double value, {int decimals = 2}) {
    return value.toStringAsFixed(decimals);
  }

  String formatRangeLabel() {
    final range = activeRange;

    String two(int value) => value.toString().padLeft(2, '0');
    String date(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';
    String dateTime(DateTime d) =>
        '${date(d)} ${two(d.hour)}:${two(d.minute)}';

    return '${dateTime(range.start)} · ${dateTime(range.end)}';
  }

  Future<void> exportPdf() async {
    if (exporting) return;

    try {
      exporting = true;
      errorMessage = null;
      notifyListeners();

      final seriesData = series;
      final pdf = pw.Document();

      const primary = PdfColor.fromInt(0xFF2563EB);
      const border = PdfColor.fromInt(0xFFE2E8F0);
      const bg = PdfColor.fromInt(0xFFF8FAFC);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: bg,
                  borderRadius: pw.BorderRadius.circular(16),
                  border: pw.Border.all(color: border),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Informe analítico',
                      style: pw.TextStyle(fontSize: 22,
                        fontWeight: pw.FontWeight.bold, color: primary),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Ámbito: ${selectedScope?.label ?? 'Sin selección'}'),
                    pw.Text('Rango: ${formatRangeLabel()}'),
                    pw.Text('Muestras analizadas: ${samples.length}'),
                    pw.Text('Consumo del rango: ${formatNumber(rangeConsumptionWh)} Wh'),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  statBox('Consumo rango',
                    '${formatNumber(rangeConsumptionWh)} Wh',
                    border,
                  ),
                  statBox('Potencia media',
                    '${formatNumber(seriesData.averagePowerW)} W',
                    border,
                  ),
                  statBox('Voltaje medio',
                    '${formatNumber(seriesData.averageVoltageV)} V',
                    border,
                  ),
                  statBox('Corriente media',
                    '${formatNumber(seriesData.averageCurrentA, decimals: 3)} A',
                    border,
                  ),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (error) {
      errorMessage = ErrorMapper.mapFailure(error).message;
    } finally {
      exporting = false;
      notifyListeners();
    }
  }

  pw.Widget statBox(String label, String value, PdfColor border) {
    return pw.Container(
      width: 124,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: border),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}