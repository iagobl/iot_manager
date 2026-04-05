import 'package:flutter/material.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/presentation/controllers/device_charts_controller.dart';

class DeviceChartsSection extends StatefulWidget {
  const DeviceChartsSection({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.deviceHost,
    required this.remoteDatasource,
  });

  final String deviceId;
  final String deviceName;
  final String deviceHost;
  final DevicesRemoteDatasource remoteDatasource;

  @override
  State<DeviceChartsSection> createState() => DeviceChartsSectionState();
}

class DeviceChartsSectionState extends State<DeviceChartsSection>
    with AutomaticKeepAliveClientMixin {
  late DeviceChartsController controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    createController();
  }

  @override
  void didUpdateWidget(covariant DeviceChartsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.deviceId != widget.deviceId) {
      controller.removeListener(refresh);
      controller.dispose();
      createController();
    }
  }

  void createController() {
    controller = DeviceChartsController(
      deviceId: widget.deviceId,
      remoteDatasource: widget.remoteDatasource,
    );
    controller.addListener(refresh);
    controller.init();
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> onExportPdf() async {
    try {
      await controller.exportCompleteReportPdf(
        deviceName: widget.deviceName,
        deviceHost: widget.deviceHost,
      );

      showMessage('Informe PDF generado correctamente.');
    } catch (_) {
      showMessage(controller.errorMessage ?? 'No se pudo generar el informe PDF.');
    }
  }

  Future<void> onRefresh() async {
    await controller.reload();

    final message = controller.errorMessage;
    if (message != null && message.isNotEmpty) {
      showMessage(message);
    }
  }

  void onMetricChanged(ChartMetric metric) {
    controller.clearError();
    controller.setMetric(metric);
  }

  void onRangeChanged(ChartRange range) {
    controller.clearError();
    controller.setRange(range);
  }

  @override
  void dispose() {
    controller.removeListener(refresh);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final data = controller.chartData;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ChartsHeroHeader(
            deviceName: widget.deviceName,
            metric: controller.metric,
            range: controller.range,
            exportingPdf: controller.exportingPdf,
            onExportPdf: onExportPdf,
          ),
          const SizedBox(height: 14),
          SelectorCard(
            metric: controller.metric,
            range: controller.range,
            onMetricChanged: onMetricChanged,
            onRangeChanged: onRangeChanged,
          ),
          const SizedBox(height: 14),
          if (controller.loading && controller.rows.isEmpty)
            const ChartsLoadingState()
          else if (controller.errorMessage != null && controller.rows.isEmpty)
            ChartsErrorState(
              error: controller.errorMessage!,
              onRetry: controller.reload,
            )
          else ...[
              if (controller.refreshing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              ChartSummaryCard(
                title: data.title,
                subtitle: data.subtitle,
                unit: data.unit,
                total: data.total,
                average: data.average,
                min: data.min,
                max: data.max,
                latestValue: data.latestValue,
                isConsumption: controller.metric == ChartMetric.consumption,
              ),
              const SizedBox(height: 12),
              LineChartCard(
                data: data,
                metric: controller.metric,
                range: controller.range,
              ),
              if (controller.errorMessage != null) ...[
                const SizedBox(height: 12),
                InlineInfoCard(message: controller.errorMessage!),
              ],
            ],
        ],
      ),
    );
  }
}

class ChartsHeroHeader extends StatelessWidget {
  const ChartsHeroHeader({
    super.key,
    required this.deviceName,
    required this.metric,
    required this.range,
    required this.exportingPdf,
    required this.onExportPdf,
  });

  final String deviceName;
  final ChartMetric metric;
  final ChartRange range;
  final bool exportingPdf;
  final Future<void> Function() onExportPdf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.12),
            scheme.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.show_chart_rounded,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monitor de gráficas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(deviceName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: exportingPdf ? null : onExportPdf,
                icon: exportingPdf ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                  ),
                ) : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(exportingPdf ? 'Generando...' : 'PDF'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              HeaderChip(
                icon: metricIcon(metric),
                label: chartMetricLabel(metric),
              ),
              HeaderChip(
                icon: Icons.schedule_rounded,
                label: chartRangeLabel(range),
              ),
              const HeaderChip(
                icon: Icons.sync_rounded,
                label: 'Actualización automática',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeaderChip extends StatelessWidget {
  const HeaderChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class SelectorCard extends StatelessWidget {
  const SelectorCard({
    super.key,
    required this.metric,
    required this.range,
    required this.onMetricChanged,
    required this.onRangeChanged,
  });

  final ChartMetric metric;
  final ChartRange range;
  final ValueChanged<ChartMetric> onMetricChanged;
  final ValueChanged<ChartRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: SelectorColumn<ChartMetric>(
                title: 'Métrica',
                value: metric,
                items: const [
                  PillItem(
                    value: ChartMetric.consumption,
                    label: 'Consumo',
                    icon: Icons.bolt_outlined,
                  ),
                  PillItem(
                    value: ChartMetric.power,
                    label: 'Potencia',
                    icon: Icons.flash_on_outlined,
                  ),
                  PillItem(
                    value: ChartMetric.voltage,
                    label: 'Voltaje',
                    icon: Icons.electrical_services_outlined,
                  ),
                ],
                onChanged: onMetricChanged,
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 1,
              color: scheme.outline.withValues(alpha: 0.10),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SelectorColumn<ChartRange>(
                title: 'Período',
                value: range,
                items: const [
                  PillItem(value: ChartRange.today, label: 'Hoy'),
                  PillItem(value: ChartRange.week, label: '7 días'),
                  PillItem(value: ChartRange.month, label: '30 días'),
                ],
                onChanged: onRangeChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SelectorColumn<T> extends StatelessWidget {
  const SelectorColumn({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<PillItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PillButton<T>(
              item: item,
              selected: item.value == value,
              onTap: () => onChanged(item.value),
            ),
          ),
        ),
      ],
    );
  }
}

class PillItem<T> {
  const PillItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

class PillButton<T> extends StatelessWidget {
  const PillButton({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final PillItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? scheme.primary.withValues(alpha: 0.24)
                : scheme.outline.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: 16,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartSummaryCard extends StatelessWidget {
  const ChartSummaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.total,
    required this.average,
    required this.min,
    required this.max,
    required this.latestValue,
    required this.isConsumption,
  });

  final String title;
  final String subtitle;
  final String unit;
  final double? total;
  final double? average;
  final double? min;
  final double? max;
  final double? latestValue;
  final bool isConsumption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              LiveValueBadge(
                label: 'Último valor',
                value: formatChartValue(
                  isConsumption ? total : latestValue,
                  unit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: isConsumption ? 'Total' : 'Media',
                  value: formatChartValue(
                    isConsumption ? total : average,
                    unit,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: 'Mínimo',
                  value: formatChartValue(min, unit),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: 'Máximo',
                  value: formatChartValue(max, unit),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LiveValueBadge extends StatelessWidget {
  const LiveValueBadge({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.08),
            scheme.primary.withValues(alpha: 0.16),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class LineChartCard extends StatelessWidget {
  const LineChartCard({
    super.key,
    required this.data,
    required this.metric,
    required this.range,
  });

  final PreparedChartData data;
  final ChartMetric metric;
  final ChartRange range;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        height: 390,
        child: data.points.isNotEmpty ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(data.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                MonitorStatusPill(label: monitorCaption(metric, range)),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                  ),
                  child: CustomPaint(
                    painter: AdvancedLinePainter(
                      data: data,
                      drawHeader: false,
                      pdfMode: false,
                      showXAxisLabels: false,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ],
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(data.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Aún no hay datos suficientes para mostrar la gráfica.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class MonitorStatusPill extends StatelessWidget {
  const MonitorStatusPill({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class ChartsLoadingState extends StatelessWidget {
  const ChartsLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class ChartsErrorState extends StatelessWidget {
  const ChartsErrorState({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Icon(Icons.show_chart_rounded, size: 36, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text('No se pudieron cargar las gráficas',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(error,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class InlineInfoCard extends StatelessWidget {
  const InlineInfoCard({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
    );
  }
}

IconData metricIcon(ChartMetric metric) {
  switch (metric) {
    case ChartMetric.consumption:
      return Icons.bolt_outlined;
    case ChartMetric.power:
      return Icons.flash_on_outlined;
    case ChartMetric.voltage:
      return Icons.electrical_services_outlined;
  }
}

String monitorCaption(ChartMetric metric, ChartRange range) {
  final metricLabel = chartMetricLabel(metric);
  switch (range) {
    case ChartRange.today:
      return '$metricLabel en seguimiento';
    case ChartRange.week:
      return '$metricLabel semanal';
    case ChartRange.month:
      return '$metricLabel mensual';
  }
}