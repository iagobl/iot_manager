import 'dart:math' as math;
import 'dart:typed_data';

import 'package:iot_manager/features/reports/domain/entities/report_models.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReportPdfDatasource {
  Future<Uint8List> buildPdf(ConsumptionReportData data) async {
    final pdf = pw.Document(version: PdfVersion.pdf_1_5, compress: true);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme(),
        maxPages: 4,
        build: (context) => [
          header(data),
          pw.SizedBox(height: 12),
          kpiGrid(data),
          pw.SizedBox(height: 12),
          sectionTitle('Consumo y coste por hora'),
          hourlyCostChart(data),
          pw.SizedBox(height: 8),
          hourlyTable(data),
          pw.NewPage(),
          sectionTitle('Información del dispositivo o conjunto'),
          devicesTable(data),
          pw.SizedBox(height: 12),
          sectionTitle('Incidencias del periodo'),
          incidentsTable(data),
          pw.SizedBox(height: 12),
          sectionTitle('Resumen técnico'),
          technicalSummary(data),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
      ),
    );

    return pdf.save();
  }

  pw.PageTheme pageTheme() {
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 24),
      theme: pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
    );
  }

  pw.Widget header(ConsumptionReportData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#1E4E7A'),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Informe de consumo eléctrico', style: pw.TextStyle(fontSize: 20, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(data.scopeLabel, style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
              pw.Text('${date(data.query.from)} - ${dateTime(data.query.to)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Generado', style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)),
              pw.Text(dateTime(data.generatedAt), style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
              pw.SizedBox(height: 6),
              pw.Text('PVPC estimado', style: pw.TextStyle(fontSize: 12, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget kpiGrid(ConsumptionReportData data) {
    final items = [
      ('Consumo total', formatEnergy(data.totalEnergyWh)),
      ('Coste estimado', formatMoney(data.totalCostEur)),
      ('Precio medio', '${data.averagePriceEurKwh.toStringAsFixed(4)} EUR/kWh'),
      ('Potencia media', '${data.averagePowerW.toStringAsFixed(1)} W'),
      ('Pico potencia', '${data.peakPowerW.toStringAsFixed(1)} W'),
      ('Muestras', '${data.samples.length}'),
    ];

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) => pw.Container(
        width: 168,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#EFF6FF'),
          borderRadius: pw.BorderRadius.circular(10),
          border: pw.Border.all(color: PdfColor.fromHex('#BFDBFE')),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(item.$1, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 3),
            pw.Text(item.$2, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
          ],
        ),
      ),
      ).toList(),
    );
  }

  pw.Widget sectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E3A8A'))),
    );
  }

  pw.Widget hourlyCostChart(ConsumptionReportData data) {
    final rows = compactHourlyRows(data.hourlyCosts, maxRows: 28);

    if (rows.isEmpty) {
      return emptyBox('No hay datos suficientes para calcular el coste por hora.');
    }

    final maxEnergy = rows.fold<double>(0, (max, row) => math.max(max, row.energyWh));
    final maxCost = rows.fold<double>(0, (max, row) => math.max(max, row.costEur));
    const chartHeight = 72.0;

    return pw.Container(
      height: 138,
      padding: const pw.EdgeInsets.all(10),
      decoration: boxDecoration(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                  chartLegendItem(PdfColor.fromHex('#2563EB'), 'Consumo (Wh)'),
                  pw.SizedBox(width: 10),
                  chartLegendItem(PdfColor.fromHex('#F97316'), 'Coste (EUR)'),
                ],
              ),
              pw.Text(
                'Escala logarítmica',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Text(
                'Máx. ${formatEnergy(maxEnergy)} / ${formatMoney(maxCost)}',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: rows.map((row) {
                final energyHeight = logBarHeight(
                  value: row.energyWh,
                  maxValue: maxEnergy,
                  maxHeight: chartHeight,
                );
                final costHeight = logBarHeight(
                  value: row.costEur,
                  maxValue: maxCost,
                  maxHeight: chartHeight,
                );

                return pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Container(
                            width: 5,
                            height: energyHeight,
                            color: PdfColor.fromHex('#2563EB'),
                          ),
                          pw.SizedBox(width: 2),
                          pw.Container(
                            width: 5,
                            height: costHeight,
                            color: PdfColor.fromHex('#F97316'),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(shortHour(row.hour), style: const pw.TextStyle(fontSize: 6)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget chartLegendItem(PdfColor color, String label) {
    return pw.Row(
      children: [
        pw.Container(width: 7, height: 7, color: color),
        pw.SizedBox(width: 3),
        pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
      ],
    );
  }

  double logBarHeight({
    required double value,
    required double maxValue,
    required double maxHeight,
  }) {
    if (value <= 0 || maxValue <= 0) return 0;

    final safeMax = math.max(value, maxValue);
    final denominator = math.log(1 + safeMax);
    if (denominator <= 0) return 0;

    final ratio = math.log(1 + value) / denominator;
    return math.max(3, ratio.clamp(0.0, 1.0) * maxHeight);
  }

  pw.Widget hourlyTable(ConsumptionReportData data) {
    final rows = compactHourlyRows(data.hourlyCosts, maxRows: 18);
    return pw.TableHelper.fromTextArray(
      border: null,
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#DBEAFE')),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
      headers: const ['Hora/Día', 'Consumo', 'PVPC', 'Coste'],
      data: rows.map((row) => [
        shortDateHour(row.hour),
        formatEnergy(row.energyWh),
        '${row.priceEurKwh.toStringAsFixed(4)} EUR/kWh',
        formatMoney(row.costEur),
      ],
      ).toList(),
    );
  }

  pw.Widget devicesTable(ConsumptionReportData data) {
    return pw.TableHelper.fromTextArray(
      border: null,
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#DBEAFE')),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      headers: const ['Nombre', 'Tipo', 'Host/IP', 'Límites configurados'],
      data: data.devices.map((device) => [
        device.name,
        device.type,
        device.identifier.isEmpty ? '-' : device.identifier,
        'P: ${limit(device.maxPowerW, 'W')} · '
            'V: ${limit(device.maxVoltageV, 'V')} · '
            'I: ${limit(device.maxCurrentA, 'A')}',
      ],
      ).toList(),
    );
  }

  pw.Widget incidentsTable(ConsumptionReportData data) {
    if (data.incidents.isEmpty) {
      return emptyBox('No se registraron incidencias en el periodo seleccionado.');
    }

    return pw.TableHelper.fromTextArray(
      border: null,
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#FEE2E2')),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      headers: const ['Fecha', 'Dispositivo', 'Incidencia', 'Detalle'],
      data: data.incidents.take(8).map((incident) => [
        dateTime(incident.createdAt),
        incident.deviceName,
        incident.title,
        incident.description.isEmpty ? '-' : incident.description,
      ],
      ).toList(),
    );
  }

  pw.Widget technicalSummary(ConsumptionReportData data) {
    final withPrice = data.hourlyCosts
        .where((item) => item.priceEurKwh > 0)
        .toList();

    final cheapest = [...withPrice]
      ..sort((a, b) => a.priceEurKwh.compareTo(b.priceEurKwh));

    final mostExpensive = [...withPrice]
      ..sort((a, b) => b.priceEurKwh.compareTo(a.priceEurKwh));

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: boxDecoration(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Tensión máxima: ${data.peakVoltageV.toStringAsFixed(1)} V · '
              'Intensidad máxima: ${data.peakCurrentA.toStringAsFixed(2)} A',
          ),
          pw.Text('Horas con precio disponible: ${withPrice.length} · '
              'Fuente: ${data.prices.isEmpty ? 'No disponible' : data.prices.first.source}',
          ),
          if (cheapest.isNotEmpty)
            pw.Text('Hora más barata: ${shortDateHour(cheapest.first.hour)} '
                '(${cheapest.first.priceEurKwh.toStringAsFixed(4)} EUR/kWh)',
            ),
          if (mostExpensive.isNotEmpty)
            pw.Text('Hora más cara: ${shortDateHour(mostExpensive.first.hour)} '
                '(${mostExpensive.first.priceEurKwh.toStringAsFixed(4)} EUR/kWh)',
            ),
          pw.SizedBox(height: 4),
          pw.Text('Nota: el coste es una estimación basada en la energía registrada '
              'por el dispositivo y el precio horario PVPC. No incluye potencia '
              'contratada, alquiler de contador, impuestos, descuentos ni otros '
              'conceptos de la factura.',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget emptyBox(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: boxDecoration(),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }

  pw.BoxDecoration boxDecoration() {
    return pw.BoxDecoration(
      color: PdfColors.white,
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: PdfColor.fromHex('#D1D5DB')),
    );
  }

  List<ReportHourlyCost> compactHourlyRows(
      List<ReportHourlyCost> rows, {required int maxRows,}) {
    if (rows.length <= maxRows) return rows;
    final step = (rows.length / maxRows).ceil();
    final result = <ReportHourlyCost>[];

    for (var i = 0; i < rows.length; i += step) {
      final group = rows.skip(i).take(step).toList();
      final energy = group.fold<double>(0, (sum, row) => sum + row.energyWh);
      final cost = group.fold<double>(0, (sum, row) => sum + row.costEur);
      final avgPrice = energy <= 0 ? 0.0 : cost / (energy / 1000);

      result.add(ReportHourlyCost(
        hour: group.first.hour,
        energyWh: energy,
        priceEurKwh: avgPrice,
        costEur: cost,
      ),
      );
    }

    return result;
  }

  String formatEnergy(double wh) {
    if (wh < 1000) {
      return '${wh.toStringAsFixed(2)} Wh';
    }
    return '${(wh / 1000).toStringAsFixed(3)} kWh';
  }

  String formatMoney(double eur) {
    if (eur <= 0) return '0.0000 EUR';

    if (eur < 0.01) {
      return '${eur.toStringAsFixed(5)} EUR';
    }

    return '${eur.toStringAsFixed(2)} EUR';
  }

  String limit(double? value, String unit) {
    if (value == null || value <= 0) return '-';

    return '${value.toStringAsFixed(unit == 'A' ? 2 : 0)} $unit';
  }

  String date(DateTime date) {
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  String dateTime(DateTime date) {
    return '${this.date(date)} ${two(date.hour)}:${two(date.minute)}';
  }

  String shortHour(DateTime date) {
    return '${two(date.hour)}h';
  }

  String shortDateHour(DateTime date) {
    return '${two(date.day)}/${two(date.month)} ${two(date.hour)}h';
  }

  String two(int value) {
    return value.toString().padLeft(2, '0');
  }
}
