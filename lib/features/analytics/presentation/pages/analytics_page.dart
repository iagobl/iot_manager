import 'package:flutter/material.dart';
import 'package:iot_manager/core/widgets/app_page_background.dart';
import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';
import 'package:iot_manager/features/analytics/presentation/controllers/analytics_controller.dart';
import 'package:iot_manager/features/analytics/presentation/widgets/analytics_chart.dart';
import 'package:iot_manager/features/analytics/presentation/widgets/analytics_summary.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => AnalyticsPageState();
}

class AnalyticsPageState extends State<AnalyticsPage> {
  late final AnalyticsController controller;
  AnalyticsChartMode todayMode = AnalyticsChartMode.todayBands;
  bool filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    controller = AnalyticsController()..addListener(refresh);
    controller.init();
  }

  @override
  void dispose() {
    controller.removeListener(refresh);
    controller.dispose();
    super.dispose();
  }

  void refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: controller.activeRange,
      saveText: 'Aplicar',
      locale: const Locale('es'),
    );

    if (picked != null) {
      await controller.selectCustomRange(
        DateTimeRange(
          start: DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
          end: DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          ),
        ),
      );
    }
  }

  AnalyticsChartMode resolveChartMode() {
    switch (controller.selectedPreset) {
      case AnalyticsRangePreset.today:
        return todayMode;
      case AnalyticsRangePreset.last7Days:
        return AnalyticsChartMode.weekDays;
      case AnalyticsRangePreset.last30Days:
        return AnalyticsChartMode.rangePeriods;
      case AnalyticsRangePreset.custom:
        final days =
            controller.activeRange.end.difference(controller.activeRange.start).inDays + 1;
        return days <= 7 ? AnalyticsChartMode.weekDays
            : AnalyticsChartMode.rangePeriods;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final series = controller.series;

    final showTodayModes = controller.selectedPreset == AnalyticsRangePreset.today;
    final chartMode = resolveChartMode();

    return AppPageBackground(
      variant: AppPageBackgroundVariant.homeSoft,
      child: RefreshIndicator(
        onRefresh: controller.reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            HeroCard(
              scopeLabel: controller.selectedScope?.label ?? 'Sin seleccionar',
              rangeLabel: controller.formatRangeLabel(),
              exporting: controller.exporting,
              onExport: controller.exportPdf,
            ),
            const SizedBox(height: 16),
            FiltersCard(
              controller: controller,
              onCustomRangeTap: pickCustomRange,
              expanded: filtersExpanded,
              onToggleExpanded: () {
                setState(() {filtersExpanded = !filtersExpanded;});
              },
            ),
            const SizedBox(height: 18),
            const SectionDivider(label: 'Resumen del periodo'),
            const SizedBox(height: 18),
            if (controller.loading && !controller.hasData)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.errorMessage != null && !controller.hasData)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(controller.errorMessage!,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              )
            else ...[
                AnalyticsSummary(
                  series: series,
                  currentPowerW: controller.currentPowerW,
                  totalConsumptionWh: controller.rangeConsumptionWh,
                  isOn: controller.isCurrentlyOn,
                ),
                const SizedBox(height: 18),
                AnalyticsChart(
                  series: series,
                  range: controller.activeRange,
                  mode: chartMode,
                  showTodayModeSelector: showTodayModes,
                  onModeChanged: (value) {
                    setState(() {todayMode = value;});
                  },
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class SectionDivider extends StatelessWidget {
  const SectionDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: scheme.outlineVariant.withOpacity(0.7),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: scheme.outlineVariant.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class HeroCard extends StatelessWidget {
  const HeroCard({
    required this.scopeLabel,
    required this.rangeLabel,
    required this.exporting,
    required this.onExport,
  });

  final String scopeLabel;
  final String rangeLabel;
  final bool exporting;
  final Future<void> Function() onExport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withOpacity(0.14),
            scheme.surface.withOpacity(0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: scheme.primary.withOpacity(0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.query_stats_rounded,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Centro analítico',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Comparativa visual del consumo agrupada por periodos temporales.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoChip(
                icon: Icons.layers_rounded,
                label: scopeLabel,
              ),
              InfoChip(
                icon: Icons.schedule_rounded,
                label: rangeLabel,
              ),
              const InfoChip(
                icon: Icons.bar_chart_rounded,
                label: 'Histograma comparativo',
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: exporting ? null : onExport,
            icon: exporting ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  scheme.onPrimary,
                ),
              ),
            )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(exporting ? 'Generando PDF...' : 'Exportar informe PDF'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 14,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ],
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({
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
        color: scheme.surface.withOpacity(0.84),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Text(label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class FiltersCard extends StatelessWidget {
  const FiltersCard({
    required this.controller,
    required this.onCustomRangeTap,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final AnalyticsController controller;
  final Future<void> Function() onCustomRangeTap;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggleExpanded,
            child: Row(
              children: [
                Expanded(
                  child: Text('Filtros de análisis',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.0 : 0.5,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.keyboard_arrow_up_rounded,
                    color: scheme.onSurfaceVariant, size: 28,),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('Selecciona el ámbito y el rango temporal del análisis.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState:
            expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                const SizedBox(height: 16),
                DropdownButtonFormField<AnalyticsScopeOption>(
                  value: controller.selectedScope,
                  items: controller.scopes.map((scope) => DropdownMenuItem(
                      value: scope,
                      child: Text(scope.label),
                    ),
                  ).toList(),
                  onChanged: (value) {
                    if (value != null) {controller.selectScope(value);}
                  },
                  decoration: const InputDecoration(
                    labelText: 'Ámbito',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    RangeChip(
                      label: 'Hoy',
                      selected:
                      controller.selectedPreset == AnalyticsRangePreset.today,
                      onTap: () => controller.selectPreset(
                        AnalyticsRangePreset.today,
                      ),
                    ),
                    RangeChip(
                      label: 'Semana actual',
                      selected:
                      controller.selectedPreset == AnalyticsRangePreset.last7Days,
                      onTap: () => controller.selectPreset(
                        AnalyticsRangePreset.last7Days,
                      ),
                    ),
                    RangeChip(
                      label: 'Este mes',
                      selected:
                      controller.selectedPreset == AnalyticsRangePreset.last30Days,
                      onTap: () => controller.selectPreset(
                        AnalyticsRangePreset.last30Days,
                      ),
                    ),
                    RangeChip(
                      label: 'Personalizado',
                      selected:
                      controller.selectedPreset == AnalyticsRangePreset.custom,
                      onTap: onCustomRangeTap,
                    ),
                  ],
                ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class RangeChip extends StatelessWidget {
  const RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: scheme.primary.withOpacity(0.14),
      side: BorderSide(
        color: selected ? scheme.primary.withOpacity(0.25)
            : scheme.outlineVariant,
      ),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}