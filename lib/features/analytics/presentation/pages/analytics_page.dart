import 'package:flutter/material.dart';
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
  AnalyticsChartMode todayMode = AnalyticsChartMode.todayBands;
  bool filtersExpanded = false;

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
        ? (controller.currentMomentChartSeries.isEmpty
        ? state.series
        : controller.currentMomentChartSeries)
        : state.series;

    return Stack(
      children: [
        RefreshIndicator(
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
      ],
    );
  }
}

class FiltersCard extends StatelessWidget {
  const FiltersCard({
    super.key,
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
                        ? 'Dispositivo'
                        : 'Conjunto',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
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
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    RangeChip(
                      label: 'Hoy',
                      selected: state.rangePreset == AnalyticsRangePreset.today,
                      onTap: () => controller.selectRangePreset(
                        AnalyticsRangePreset.today,
                      ),
                    ),
                    RangeChip(
                      label: '7 días',
                      selected:
                      state.rangePreset == AnalyticsRangePreset.last7Days,
                      onTap: () => controller.selectRangePreset(
                        AnalyticsRangePreset.last7Days,
                      ),
                    ),
                    RangeChip(
                      label: 'Personalizado',
                      selected: state.rangePreset == AnalyticsRangePreset.custom,
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

class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.scopeLabel,
    required this.rangeLabel,
    required this.exporting,
    required this.onExport,
  });

  final String scopeLabel;
  final String rangeLabel;
  final bool exporting;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            scheme.primary.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle(
              style: TextStyle(color: scheme.onPrimary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Análisis de consumo',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    scopeLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rangeLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.90),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          FilledButton.tonalIcon(
            onPressed: exporting ? null : onExport,
            icon: exporting
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.picture_as_pdf_rounded),
            label: Text(exporting ? 'Exportando' : 'PDF'),
            style: FilledButton.styleFrom(
              backgroundColor:
              scheme.onPrimary.withValues(alpha: 0.14),
              foregroundColor: scheme.onPrimary,
              padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class ScopeGroupCard extends StatelessWidget {
  const ScopeGroupCard({
    super.key,
    required this.title,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bgColor = selected
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest.withValues(
      alpha: enabled ? 0.75 : 0.45,
    );

    final fgColor = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurface.withValues(
      alpha: enabled ? 0.90 : 0.45,
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.65,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Center(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RangeChip extends StatelessWidget {
  const RangeChip({
    super.key,
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

    return Material(
      color: selected
          ? scheme.primaryContainer
          : scheme.surface.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
              ],
              Text(label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionDivider extends StatelessWidget {
  const SectionDivider({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Text(label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
