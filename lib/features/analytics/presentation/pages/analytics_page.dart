import 'package:flutter/material.dart';
import 'package:iot_manager/core/widgets/app_page_background.dart';
import 'package:iot_manager/features/analytics/domain/entities/analytics_models.dart';
import 'package:iot_manager/features/analytics/presentation/controllers/analytics_controller.dart';
import 'package:iot_manager/features/analytics/presentation/widgets/analytics_chart.dart';
import 'package:iot_manager/features/analytics/presentation/widgets/analytics_summary.dart'
as analytics_widgets;

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => AnalyticsPageState();
}

class AnalyticsPageState extends State<AnalyticsPage> {
  late final AnalyticsController controller;
  AnalyticsChartMode todayMode = AnalyticsChartMode.currentMoment;
  bool filtersExpanded = true;

  @override
  void initState() {
    super.initState();
    controller = AnalyticsController()..addListener(refresh)..initialize();
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
    final state = controller.state;
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1, now.month, now.day);
    final lastDate = DateTime(now.year, now.month, now.day);

    DateTime safeStart = DateTime(
      state.from.year,
      state.from.month,
      state.from.day,
    );
    DateTime safeEnd = DateTime(
      state.to.year,
      state.to.month,
      state.to.day,
    );

    if (safeStart.isBefore(firstDate)) safeStart = firstDate;
    if (safeStart.isAfter(lastDate)) safeStart = lastDate;
    if (safeEnd.isBefore(firstDate)) safeEnd = firstDate;
    if (safeEnd.isAfter(lastDate)) safeEnd = lastDate;
    if (safeEnd.isBefore(safeStart)) safeEnd = safeStart;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: DateTimeRange(start: safeStart, end: safeEnd),
      saveText: 'Aplicar',
      helpText: 'Selecciona un rango',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      builder: (context, child) {
        final scheme = Theme.of(context).colorScheme;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: scheme.copyWith(
              primary: scheme.primary,
              surface: scheme.surface,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.setCustomRange(
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

  AnalyticsChartMode resolveChartMode(AnalyticsState state) {
    switch (state.rangePreset) {
      case AnalyticsRangePreset.today:
        return todayMode;
      case AnalyticsRangePreset.last7Days:
        return AnalyticsChartMode.weekDays;
      case AnalyticsRangePreset.last30Days:
        return AnalyticsChartMode.rangePeriods;
      case AnalyticsRangePreset.custom:
        final days = state.to.difference(state.from).inDays + 1;
        if (days <= 1) {
          return AnalyticsChartMode.todayBands;
        }
        if (days <= 7) {
          return AnalyticsChartMode.weekDays;
        }
        return AnalyticsChartMode.rangePeriods;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = controller.state;
    final chartMode = resolveChartMode(state);
    final showTodayModes = state.rangePreset == AnalyticsRangePreset.today;
    final chartSeries = chartMode == AnalyticsChartMode.currentMoment
        ? controller.currentMomentChartSeries : state.series;

    return AppPageBackground(
      variant: AppPageBackgroundVariant.homeSoft,
      child: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            HeroCard(
              scopeLabel: state.selectedScope?.label ?? 'Sin seleccionar',
              rangeLabel: controller.rangeLabel(),
              exporting: state.exporting,
              onExport: () => controller.exportPdf(context),
            ),
            const SizedBox(height: 16),
            FiltersCard(
              controller: controller,
              state: state,
              expanded: filtersExpanded,
              onToggleExpanded: () {
                setState(() {
                  filtersExpanded = !filtersExpanded;
                });
              },
              onCustomRangeTap: pickCustomRange,
            ),
            const SizedBox(height: 18),
            const SectionDivider(label: 'Resumen del periodo'),
            const SizedBox(height: 18),
            if (state.loading && state.series.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.errorMessage != null && state.series.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              )
            else ...[
                analytics_widgets.AnalyticsSummary(
                  series: state.series,
                  currentPowerW: controller.currentPowerW,
                  totalConsumptionWh: controller.rangeConsumptionWh,
                  averagePowerW: controller.displayAveragePowerW,
                  peakPowerW: controller.displayPeakPowerW,
                  isOn: controller.isCurrentlyOn,
                ),
                const SizedBox(height: 18),
                AnalyticsChart(
                  series: chartSeries,
                  range: DateTimeRange(start: state.from, end: state.to),
                  mode: chartMode,
                  showTodayModeSelector: showTodayModes,
                  onModeChanged: (value) {
                    setState(() {
                      todayMode = value;
                    });
                  },
                  normalizationLimits: state.normalizationLimits,
                  aggregateMode: state.selectedGroup == AnalyticsScopeGroup.global,
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class FiltersCard extends StatelessWidget {
  const FiltersCard({super.key,
    required this.controller,
    required this.state,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onCustomRangeTap,
  });

  final AnalyticsController controller;
  final AnalyticsState state;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final Future<void> Function() onCustomRangeTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final globalScopes = controller.scopesForGroup(AnalyticsScopeGroup.global);
    final deviceScopes = controller.scopesForGroup(AnalyticsScopeGroup.device);
    final visibleScopes = controller.scopesForGroup(state.selectedGroup);
    String? selectedScopeId;

    if (state.selectedScope != null &&
        visibleScopes.any((item) => item.id == state.selectedScope!.id)) {
      selectedScopeId = state.selectedScope!.id;
    } else if (visibleScopes.isNotEmpty) {
      selectedScopeId = visibleScopes.first.id;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.65),
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
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 28,
                  ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const SectionLabel(label: 'Ámbito'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ScopeGroupCard(
                        title: 'Conjuntos',
                        selected: state.selectedGroup == AnalyticsScopeGroup.global,
                        enabled: globalScopes.isNotEmpty,
                        onTap: globalScopes.isEmpty ? null : () => controller.selectGroup(
                          AnalyticsScopeGroup.global,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ScopeGroupCard(
                        title: 'Dispositivo',
                        selected: state.selectedGroup == AnalyticsScopeGroup.device,
                        enabled: deviceScopes.isNotEmpty,
                        onTap: deviceScopes.isEmpty ? null : () => controller.selectGroup(
                          AnalyticsScopeGroup.device,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedScopeId,
                  decoration: InputDecoration(
                    labelText: state.selectedGroup == AnalyticsScopeGroup.device
                        ? 'Selecciona dispositivo' : 'Selecciona conjunto',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    filled: true,
                    fillColor: scheme.surfaceContainerLowest,
                  ),
                  items: visibleScopes.map((scope) => DropdownMenuItem<String>(
                      value: scope.id,
                      child: Text(scope.label),
                    ),
                  ).toList(),
                  onChanged: visibleScopes.isEmpty ? null : (value) {
                    if (value != null) {
                      controller.selectScope(value);
                    }
                  },
                ),
                const SizedBox(height: 18),
                const SectionLabel(label: 'Rango temporal'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RangeChip(
                        label: 'Hoy',
                        selected: state.rangePreset == AnalyticsRangePreset.today,
                        onTap: () => controller.selectRangePreset(
                          AnalyticsRangePreset.today,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RangeChip(
                        label: 'Semana actual',
                        selected:
                        state.rangePreset == AnalyticsRangePreset.last7Days,
                        onTap: () => controller.selectRangePreset(
                          AnalyticsRangePreset.last7Days,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RangeChip(
                        label: 'Personalizado',
                        selected: state.rangePreset == AnalyticsRangePreset.custom,
                        onTap: () async {
                          await onCustomRangeTap();
                        },
                      ),
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

class ScopeGroupCard extends StatelessWidget {
  const ScopeGroupCard({super.key,
    required this.title,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final String title;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final backgroundColor = !enabled
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
        : selected
        ? scheme.primary.withValues(alpha: 0.10)
        : scheme.surfaceContainerLowest;

    final borderColor = !enabled
        ? scheme.outlineVariant.withValues(alpha: 0.35)
        : selected
        ? scheme.primary.withValues(alpha: 0.55)
        : scheme.outlineVariant.withValues(alpha: 0.55);

    final foregroundColor = !enabled
        ? scheme.onSurfaceVariant.withValues(alpha: 0.50)
        : selected
        ? scheme.primary
        : scheme.onSurface;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 20,
              color: foregroundColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Text(label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
    );
  }
}

class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.7),
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
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class HeroCard extends StatelessWidget {
  const HeroCard({super.key,
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
            scheme.primary.withValues(alpha: 0.14),
            scheme.surface.withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
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
                  color: scheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.query_stats_rounded, color: scheme.primary),
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
              InfoChip(icon: Icons.layers_rounded, label: scopeLabel),
              InfoChip(icon: Icons.schedule_rounded, label: rangeLabel),
              const InfoChip(
                  icon: Icons.bar_chart_rounded,
                  label: 'Histograma comparativo'
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
            ) : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(exporting ? 'Generando PDF...' : 'Exportar informe PDF'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
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
  const InfoChip({super.key,
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
        color: scheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.60)),
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

class RangeChip extends StatelessWidget {
  const RangeChip({super.key,
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.14)
              : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected
              ? scheme.primary.withValues(alpha: 0.50)
              : scheme.outlineVariant.withValues(alpha: 0.75),
          ),
          boxShadow: selected ? [BoxShadow(
              color: scheme.primary.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? scheme.primary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}