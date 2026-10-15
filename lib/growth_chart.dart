import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'date_axis.dart';
import 'growth_entry.dart';

enum GrowthMetric { weight, height }

const _kgToLb = 2.20462;
const _cmToIn = 0.393701;

typedef _Point = ({DateTime time, double value});

/// A single-metric line chart for growth measurements over time.
///
/// Entries can freely mix units per-entry (e.g. one weighed in kg, another in
/// lb) since the entry form doesn't force a single unit system. To still plot
/// a coherent line, every point is converted — purely for this chart's
/// rendering, never touching storage — to whichever unit the most recent
/// entry for [metric] used.
class GrowthChart extends StatelessWidget {
  const GrowthChart({super.key, required this.entries, required this.metric});

  final List<GrowthEntry> entries;
  final GrowthMetric metric;

  List<GrowthEntry> get _relevant {
    final filtered = entries
        .where((e) => metric == GrowthMetric.weight ? e.weight != null : e.height != null)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    return filtered;
  }

  String get _displayUnit {
    final relevant = _relevant;
    if (relevant.isEmpty) return metric == GrowthMetric.weight ? 'kg' : 'cm';
    return metric == GrowthMetric.weight ? relevant.last.weightUnit : relevant.last.heightUnit;
  }

  List<_Point> get _points {
    final relevant = _relevant;
    if (relevant.isEmpty) return [];
    final targetUnit = _displayUnit;
    return [
      for (final e in relevant)
        (
          time: e.time,
          value: metric == GrowthMetric.weight
              ? _convertWeight(e.weight!, e.weightUnit, targetUnit)
              : _convertHeight(e.height!, e.heightUnit, targetUnit),
        ),
    ];
  }

  static double _convertWeight(double value, String from, String to) {
    if (from == to) return value;
    return from == 'kg' ? value * _kgToLb : value / _kgToLb;
  }

  static double _convertHeight(double value, String from, String to) {
    if (from == to) return value;
    return from == 'cm' ? value * _cmToIn : value / _cmToIn;
  }

  static const _axisLabelStyle = TextStyle(fontSize: 10);

  static double _labelWidth(BuildContext context, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _axisLabelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }

  static double _leftAxisWidth(BuildContext context, double maxValue, String unit) =>
      _labelWidth(context, '${maxValue.toStringAsFixed(1)} $unit') + 8;

  @override
  Widget build(BuildContext context) {
    final points = _points;
    if (points.isEmpty) {
      return Center(
        child: Text(
          'No measurements yet for this chart.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    final unit = _displayUnit;
    final spots = [
      for (final p in points) FlSpot(dayNumber(p.time), p.value),
    ];
    final colorScheme = Theme.of(context).colorScheme;

    // Headroom above and below the data so the top and bottom points aren't
    // clipped by the chart border. A flat line (one point, or no change)
    // gets a fixed margin instead of a zero-height range.
    final values = points.map((p) => p.value);
    final lowest = values.reduce(math.min);
    final highest = values.reduce(math.max);
    final yPad = highest > lowest ? (highest - lowest) * 0.08 : math.max(highest.abs() * 0.05, 0.5);
    final maxY = highest + yPad;
    final leftAxisWidth = _leftAxisWidth(context, maxY, unit);

    return LayoutBuilder(
      builder: (context, constraints) {
        final axis = computeDateAxis(
          points.first.time,
          points.last.time,
          width: constraints.maxWidth - leftAxisWidth,
          dayLabelWidth: _labelWidth(context, '12/28'),
          monthLabelWidth: _labelWidth(context, "May '26"),
        );
        return LineChart(
          LineChartData(
            minX: axis.minX,
            maxX: axis.maxX,
            minY: lowest - yPad,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                color: colorScheme.primary,
              ),
            ],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  // Visit every midnight and label only the chosen ticks; the
                  // axis ends are padding, not data, so they get no label.
                  interval: 1,
                  minIncluded: false,
                  maxIncluded: false,
                  getTitlesWidget: (value, meta) {
                    if (!axis.isTick(value)) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                      child: Text(
                        axis.label(dateForDayNumber(value.round())),
                        style: _axisLabelStyle,
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: leftAxisWidth,
                  // The padded min/max would otherwise get their own labels,
                  // landing on top of the nearest regular one.
                  minIncluded: false,
                  maxIncluded: false,
                  getTitlesWidget: (value, meta) => Text(
                    '${value.toStringAsFixed(1)} $unit',
                    style: _axisLabelStyle,
                  ),
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: true),
            gridData: FlGridData(
              show: true,
              verticalInterval: 1,
              checkToShowVerticalLine: axis.isTick,
            ),
          ),
        );
      },
    );
  }
}
