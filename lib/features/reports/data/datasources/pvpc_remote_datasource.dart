import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/report_models.dart';

class PvpcRemoteDatasource {
  PvpcRemoteDatasource({http.Client? client,}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String publicBaseUrl = 'https://api.preciodelaluz.org/v1/prices/all';
  static const String esiosBaseUrl = 'https://api.esios.ree.es/indicators/1001';

  final String esiosToken = const String.fromEnvironment('ESIOS_API_KEY');

  Future<List<PvpcHourlyPrice>> fetchPrices(DateTime from, DateTime to) async {
    final normalizedFrom = DateTime(from.year, from.month, from.day);
    final normalizedTo = DateTime(to.year, to.month, to.day, 23, 59, 59);

    try {
      final publicPrices = await fetchFromPrecioDeLaLuz(normalizedFrom, normalizedTo);

      debugPrint('PVPC precios públicos obtenidos: ${publicPrices.length}');

      if (publicPrices.isNotEmpty) {
        return publicPrices;
      }
    } catch (error) {
      debugPrint('Error obteniendo precios desde preciodelaluz.org: $error');
    }

    if (esiosToken.isEmpty) {
      debugPrint('No hay token de ESIOS configurado -> devolviendo precios vacíos');
      return <PvpcHourlyPrice>[];
    }

    try {
      final esiosPrices = await _fetchFromEsios(normalizedFrom, normalizedTo);

      debugPrint('PVPC precios ESIOS obtenidos: ${esiosPrices.length}');

      return esiosPrices;
    } catch (error) {
      debugPrint('Error obteniendo precios desde ESIOS: $error');
      return <PvpcHourlyPrice>[];
    }
  }

  Future<List<PvpcHourlyPrice>> fetchFromPrecioDeLaLuz(DateTime from, DateTime to
      ) async {

    final result = <PvpcHourlyPrice>[];
    DateTime current = from;

    while (!current.isAfter(to)) {
      final date =
          '${current.year.toString().padLeft(4, '0')}-'
          '${current.month.toString().padLeft(2, '0')}-'
          '${current.day.toString().padLeft(2, '0')}';

      final uri = Uri.parse('$publicBaseUrl?zone=PCB&date=$date');
      final response = await _client.get(uri);

      if (response.statusCode != 200) {
        debugPrint('Error HTTP ${response.statusCode} en $date');
        debugPrint(response.body);

        current = current.add(const Duration(days: 1));
        continue;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      decoded.forEach((key, value) {
        try {
          final item = value as Map<String, dynamic>;
          final label = item['label']?.toString() ?? '';
          final priceRaw = item['price'];

          if (priceRaw == null) return;
          final price = (priceRaw as num).toDouble();
          final parts = label.split('-');

          if (parts.length != 2) return;
          final startHour = int.tryParse(parts[0].replaceAll('h', '').trim());

          if (startHour == null) return;
          final start = DateTime(current.year, current.month, current.day, startHour);

          result.add(
            PvpcHourlyPrice(
              start: start,
              end: start.add(const Duration(hours: 1)),
              priceEurKwh: price > 10 ? price / 1000 : price,
              source: 'preciodelaluz.org',
            ),
          );
        } catch (e) {
          debugPrint('Error parseando hora PVPC: $e');
        }
      });
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  Future<List<PvpcHourlyPrice>> _fetchFromEsios(DateTime from, DateTime to) async {
    final uri = Uri.parse(
      '$esiosBaseUrl?start_date=${from.toIso8601String()}'
          '&end_date=${to.toIso8601String()}',
    );

    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'x-api-key': esiosToken,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error ESIOS ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final indicator = decoded['indicator'] as Map<String, dynamic>;
    final values = indicator['values'] as List<dynamic>;

    return values.map((item) {
      final map = item as Map<String, dynamic>;
      final start = DateTime.parse(map['datetime'].toString());
      final value = (map['value'] as num).toDouble();

      return PvpcHourlyPrice(
        start: start,
        end: start.add(const Duration(hours: 1)),
        priceEurKwh: value / 1000,
        source: 'esios',
      );
    }).toList();
  }
}
