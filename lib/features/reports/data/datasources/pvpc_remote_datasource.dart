import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:iot_manager/features/reports/domain/entities/report_models.dart';

class PvpcRemoteDatasource {
  PvpcRemoteDatasource({http.Client? client,}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _baseUrl = 'https://api.esios.ree.es/archives/70/download_json';

  Future<List<PvpcHourlyPrice>> fetchPrices(DateTime from, DateTime to) async {
    final startDay = DateTime(from.year, from.month, from.day);
    final endDay = DateTime(to.year, to.month, to.day);

    final result = <PvpcHourlyPrice>[];

    var current = startDay;

    while (!current.isAfter(endDay)) {
      try {
        final dailyPrices = await fetchDay(current);
        result.addAll(dailyPrices);

      } catch (error, stackTrace) {
        debugPrint('Error obteniendo PVPC ${yyyyMmDd(current)}: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      current = current.add(const Duration(days: 1));
    }

    result.sort((a, b) => a.start.compareTo(b.start));
    return result.where((price) => price.end.isAfter(from) && price.start.isBefore(to)).toList();
  }

  Future<List<PvpcHourlyPrice>> fetchDay(DateTime day) async {
    final date = yyyyMmDd(day);
    final uri = Uri.parse('$_baseUrl?locale=es&date=$date');

    final response = await _client.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('ESIOS PVPC HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Respuesta PVPC inválida.');
    }

    final pvpcRows = decoded['PVPC'];
    if (pvpcRows is! List) {
      throw const FormatException('No existe la lista PVPC en la respuesta.');
    }

    final prices = <PvpcHourlyPrice>[];

    for (final row in pvpcRows) {
      if (row is! Map) continue;

      final item = Map<String, dynamic>.from(row);

      final dia = item['Dia']?.toString();
      final hora = item['Hora']?.toString();
      final pcb = item['PCB']?.toString();

      final start = parseStartDateTime(
        fallbackDay: day,
        dayText: dia,
        hourText: hora,
      );

      final priceEurMwh = parseSpanishDouble(pcb);

      if (start == null || priceEurMwh == null || priceEurMwh <= 0) {
        continue;
      }

      final priceEurKwh = priceEurMwh / 1000;

      prices.add(PvpcHourlyPrice(
          start: start,
          end: start.add(const Duration(hours: 1)),
          priceEurKwh: priceEurKwh,
          source: 'ESIOS PVPC'),
      );
    }
    return prices;
  }

  DateTime? parseStartDateTime({
    required DateTime fallbackDay,
    required String? dayText,
    required String? hourText,
  }) {
    final parsedDay = parseSpanishDate(dayText) ?? fallbackDay;
    final startHour = parseStartHour(hourText);

    if (startHour == null) return null;

    return DateTime(
      parsedDay.year,
      parsedDay.month,
      parsedDay.day,
      startHour,
    );
  }

  DateTime? parseSpanishDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final parts = value.trim().split('/');

    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return null;

    return DateTime(year, month, day);
  }

  int? parseStartHour(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final match = RegExp(r'^(\d{1,2})').firstMatch(value.trim());
    final hour = int.tryParse(match?.group(1) ?? '');

    if (hour == null || hour < 0 || hour > 23) return null;

    return hour;
  }

  double? parseSpanishDouble(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final normalized = value.trim().replaceAll('.', '').replaceAll(',', '.');

    return double.tryParse(normalized);
  }

  String yyyyMmDd(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
