import 'package:flutter/material.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/presentation/controllers/device_incidents_controller.dart';

class DeviceIncidentsSection extends StatefulWidget {
  const DeviceIncidentsSection({
    super.key,
    required this.deviceId,
    required this.remoteDatasource,
  });

  final String deviceId;
  final DevicesRemoteDatasource remoteDatasource;

  @override
  State<DeviceIncidentsSection> createState() => DeviceIncidentsSectionState();
}

class DeviceIncidentsSectionState extends State<DeviceIncidentsSection> {
  late final DeviceIncidentsController controller;

  @override
  void initState() {
    super.initState();
    controller = DeviceIncidentsController(
      deviceId: widget.deviceId,
      remoteDatasource: widget.remoteDatasource,
    )..addListener(onControllerChanged);

    controller.initialize();
  }

  void onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(onControllerChanged);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null && controller.incidents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se pudieron cargar las incidencias.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Text(
            'Incidentes registrados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          if (controller.incidents.isEmpty)
            EmptyIncidentsCard()
          else
            ...controller.incidents.map(buildIncidentCard),
        ],
      ),
    );
  }

  Widget buildIncidentCard(Map<String, dynamic> incident) {
    final colorScheme = Theme.of(context).colorScheme;

    final type = (incident['type'] ?? '').toString();
    final severity = toInt(incident['severity']);
    final message = (incident['message'] ?? '').toString().trim();
    final isAcknowledged = incident['is_acknowledged'] == true;
    final ts = parseDateTime(incident['ts']);

    final accentColor = accentColorFor(type, severity, colorScheme);
    final icon = iconFor(type, severity);
    final title = titleFor(type, severity);
    final subtitle = formatDate(ts);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: colorScheme.surface,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                icon,
                size: 24,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message.isEmpty
                        ? 'Se ha registrado una incidencia en el dispositivo.'
                        : message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  if (isAcknowledged) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Incidencia reconocida',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  static String formatDate(DateTime? value) {
    if (value == null) return 'Sin fecha';

    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year.toString();
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');

    return '$d/$m/$y — $h:$min';
  }

  static String titleFor(String type, int severity) {
    final normalized = type.toLowerCase().trim();

    if (normalized.contains('voltage')) return 'Tensión máxima superada';
    if (normalized.contains('current')) return 'Corriente máxima superada';
    if (normalized.contains('power')) return 'Potencia máxima superada';
    if (normalized.contains('temperature')) return 'Temperatura elevada';
    if (normalized.contains('offline')) return 'Dispositivo desconectado';

    if (severity >= 3) return 'Incidencia crítica detectada';
    if (severity == 2) return 'Incidencia importante detectada';
    return 'Incidencia registrada';
  }

  static IconData iconFor(String type, int severity) {
    final normalized = type.toLowerCase().trim();

    if (normalized.contains('voltage')) return Icons.bolt;
    if (normalized.contains('current')) return Icons.electrical_services;
    if (normalized.contains('power')) return Icons.flash_on;
    if (normalized.contains('temperature')) return Icons.thermostat;
    if (normalized.contains('offline')) return Icons.wifi_off;

    if (severity >= 3) return Icons.warning_amber_rounded;
    return Icons.error_outline_rounded;
  }

  static Color accentColorFor(
      String type,
      int severity,
      ColorScheme colorScheme,
      ) {
    final normalized = type.toLowerCase().trim();

    if (normalized.contains('voltage') ||
        normalized.contains('current') ||
        normalized.contains('power')) {
      return const Color(0xFFB45309);
    }

    if (normalized.contains('temperature')) {
      return colorScheme.error;
    }

    if (severity >= 3) return colorScheme.error;
    return const Color(0xFFB45309);
  }
}

class EmptyIncidentsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No hay incidencias registradas para este dispositivo.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}