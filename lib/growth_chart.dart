import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      for (final p in points) FlSpot(p.time.millisecondsSinceEpoch.toDouble(), p.value),
    ];
    final colorScheme = Theme.of(context).colorScheme;

    // fl_chart spaces bottom-axis ticks evenly across the x range by default,
    // which for measurements taken hours apart on the same day produces
    // several ticks that all format to the same calendar date. Flooring the
    // spacing at one day keeps every visible tick on a distinct date.
    const oneDayMs = Duration(days: 1);
    final xRange = spots.last.x - spots.first.x;
    final bottomInterval = math.max(oneDayMs.inMilliseconds.toDouble(), xRange / 6);

    return LineChart(
      LineChartData(
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
              interval: bottomInterval,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  DateFormat.Md().format(DateTime.fromMillisecondsSinceEpoch(value.toInt())),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) => Text(
                '${value.toStringAsFixed(1)} $unit',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        gridData: const FlGridData(show: true),
      ),
    );
  }
}
