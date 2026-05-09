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
        maxPages: 2,
        build: (context) => [
          header(data),
          pw.SizedBox(height: 12),
          kpiGrid(data),
          pw.SizedBox(height: 12),
          sectionTitle('Consumo y coste por hora'),
          hourlyCostChart(data),
          pw.SizedBox(height: 8),
          hourlyTable(data),
          pw.SizedBox(height: 12),
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
      ('Consumo total', '${(data.totalEnergyWh / 1000).toStringAsFixed(3)} kWh'),
      ('Coste estimado', '${data.totalCostEur.toStringAsFixed(2)} €'),
      ('Precio medio', '${data.averagePriceEurKwh.toStringAsFixed(4)} €/kWh'),
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
      )).toList(),
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
    final maxEnergy = rows.fold<double>(0, (max, row) => math.max(max, row.energyWh));
    final maxCost = rows.fold<double>(0, (max, row) => math.max(max, row.costEur));

    if (rows.isEmpty) {
      return emptyBox('No hay datos suficientes para calcular el coste por hora.');
    }

    return pw.Container(
      height: 126,
      padding: const pw.EdgeInsets.all(10),
      decoration: _boxDecoration(),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: rows.map((row) {
          final energyHeight = maxEnergy <= 0 ? 0.0 : (row.energyWh / maxEnergy) * 78;
          final costHeight = maxCost <= 0 ? 0.0 : (row.costEur / maxCost) * 78;
          return pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Container(width: 5, height: math.max(2, energyHeight), color: PdfColor.fromHex('#2563EB')),
                    pw.SizedBox(width: 2),
                    pw.Container(width: 5, height: math.max(2, costHeight), color: PdfColor.fromHex('#F97316')),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text(shortHour(row.hour), style: const pw.TextStyle(fontSize: 6)),
              ],
            ),
          );
        }).toList(),
      ),
    );
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
        '${row.energyWh.toStringAsFixed(1)} Wh',
        '${row.priceEurKwh.toStringAsFixed(4)} €/kWh',
        '${row.costEur.toStringAsFixed(3)} €',
      ]).toList(),
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
        'P: ${limit(device.maxPowerW, 'W')} · V: ${limit(device.maxVoltageV, 'V')} · I: ${limit(device.maxCurrentA, 'A')}',
      ]).toList(),
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
      ]).toList(),
    );
  }

  pw.Widget technicalSummary(ConsumptionReportData data) {
    final cheapest = data.hourlyCosts.where((h) => h.priceEurKwh > 0).toList()
      ..sort((a, b) => a.priceEurKwh.compareTo(b.priceEurKwh));
    final mostExpensive = [...cheapest]..sort((a, b) => b.priceEurKwh.compareTo(a.priceEurKwh));

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: _boxDecoration(),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Tensión máxima: ${data.peakVoltageV.toStringAsFixed(1)} V · Intensidad máxima: ${data.peakCurrentA.toStringAsFixed(2)} A'),
          pw.Text('Horas con precio disponible: ${data.hourlyCosts.where((h) => h.priceEurKwh > 0).length} · Fuente: ${data.prices.isEmpty ? 'No disponible' : data.prices.first.source}'),
          if (cheapest.isNotEmpty) pw.Text('Hora más barata: ${shortDateHour(cheapest.first.hour)} (${cheapest.first.priceEurKwh.toStringAsFixed(4)} €/kWh)'),
          if (mostExpensive.isNotEmpty) pw.Text('Hora más cara: ${shortDateHour(mostExpensive.first.hour)} (${mostExpensive.first.priceEurKwh.toStringAsFixed(4)} €/kWh)'),
          pw.SizedBox(height: 4),
          pw.Text('Nota: el coste es una estimación basada en energía registrada por el dispositivo y precio horario PVPC. No incluye potencia contratada, alquiler de contador, impuestos, descuentos ni otros conceptos de la factura.' , style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
      ),
    );
  }

  pw.Widget emptyBox(String text) => pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: _boxDecoration(),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
  );

  pw.BoxDecoration _boxDecoration() => pw.BoxDecoration(
    color: PdfColors.white,
    borderRadius: pw.BorderRadius.circular(10),
    border: pw.Border.all(color: PdfColor.fromHex('#D1D5DB')),
  );

  List<ReportHourlyCost> compactHourlyRows(List<ReportHourlyCost> rows, {required int maxRows}) {
    if (rows.length <= maxRows) return rows;
    final step = (rows.length / maxRows).ceil();
    final result = <ReportHourlyCost>[];
    for (var i = 0; i < rows.length; i += step) {
      final group = rows.skip(i).take(step).toList();
      final energy = group.fold<double>(0, (sum, r) => sum + r.energyWh);
      final cost = group.fold<double>(0, (sum, r) => sum + r.costEur);
      final avgPrice = energy <= 0 ? 0.0 : cost / (energy / 1000);
      result.add(ReportHourlyCost(hour: group.first.hour, energyWh: energy, priceEurKwh: avgPrice, costEur: cost));
    }
    return result;
  }

  String limit(double? value, String unit) => value == null || value <= 0 ? '-' : '${value.toStringAsFixed(unit == 'A' ? 2 : 0)} $unit';
  String date(DateTime d) => '${two(d.day)}/${two(d.month)}/${d.year}';
  String dateTime(DateTime d) => '${date(d)} ${two(d.hour)}:${two(d.minute)}';
  String shortHour(DateTime d) => '${two(d.hour)}h';
  String shortDateHour(DateTime d) => '${two(d.day)}/${two(d.month)} ${two(d.hour)}h';
  String two(int v) => v.toString().padLeft(2, '0');
}
