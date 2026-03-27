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
          ChartsHeader(
            exportingPdf: controller.exportingPdf,
            onExportPdf: onExportPdf,
          ),
          const SizedBox(height: 12),
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
                pointsCount: data.points.length,
                total: data.total,
                average: data.average,
                min: data.min,
                max: data.max,
                isConsumption: controller.metric == ChartMetric.consumption,
              ),
              const SizedBox(height: 12),
              LineChartCard(data: data),
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

class ChartsHeader extends StatelessWidget {
  const ChartsHeader({super.key,
    required this.exportingPdf,
    required this.onExportPdf,
  });

  final bool exportingPdf;
  final Future<void> Function() onExportPdf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gráficas e informes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text('Consulta el historial del dispositivo y exporta un informe en PDF.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: exportingPdf ? null : onExportPdf,
          icon: exportingPdf ? SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                scheme.onPrimary,
              ),
            ),
          ) : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(exportingPdf ? 'Generando...' : 'PDF'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ],
    );
  }
}

class SelectorCard extends StatelessWidget {
  const SelectorCard({super.key,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
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
            const SizedBox(width: 12),
            Container(
              width: 1,
              color: scheme.outline.withValues(alpha: 0.10),
            ),
            const SizedBox(width: 12),
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
  const SelectorColumn({super.key,
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
  const PillButton({super.key,
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
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.14)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? scheme.primary.withValues(alpha: 0.25)
                : scheme.outline.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: 15,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
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
  const ChartSummaryCard({super.key,
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.pointsCount,
    required this.total,
    required this.average,
    required this.min,
    required this.max,
    required this.isConsumption,
  });

  final String title;
  final String subtitle;
  final String unit;
  final int pointsCount;
  final double? total;
  final double? average;
  final double? min;
  final double? max;
  final bool isConsumption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 10) / 2;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  StatCard(
                    width: itemWidth,
                    label: isConsumption ? 'Total' : 'Media',
                    value: formatChartValue(
                      isConsumption ? total : average,
                      unit,
                    ),
                  ),
                  StatCard(
                    width: itemWidth,
                    label: 'Mínimo',
                    value: formatChartValue(min, unit),
                  ),
                  StatCard(
                    width: itemWidth,
                    label: 'Máximo',
                    value: formatChartValue(max, unit),
                  ),
                  StatCard(
                    width: itemWidth,
                    label: 'Muestras',
                    value: '$pointsCount',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key,
    required this.width,
    required this.label,
    required this.value,
  });

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.1),
          ),
        ],
      ),
    );
  }
}

class LineChartCard extends StatelessWidget {
  const LineChartCard({super.key,
    required this.data,
  });

  final PreparedChartData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: SizedBox(
        height: 340,
        child: data.points.isNotEmpty ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(data.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                  ),
                  child: CustomPaint(
                    painter: AdvancedLinePainter(
                      data: data,
                      drawHeader: false,
                      pdfMode: false,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ],
        ) : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.title,
              style: const TextStyle(fontWeight: FontWeight.w800),
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

class ChartsLoadingState extends StatelessWidget {
  const ChartsLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class ChartsErrorState extends StatelessWidget {
  const ChartsErrorState({super.key,
    required this.error,
    required this.onRetry,
  });

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Icon(Icons.show_chart_rounded, size: 34, color: scheme.onSurfaceVariant),
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
  const InlineInfoCard({super.key,
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