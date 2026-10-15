import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'date_range_filter_bar.dart';
import 'empty_state.dart';
import 'feeding_filters.dart';
import 'growth_chart.dart';
import 'growth_entry.dart';

/// The Growth tab. Like the Sleep and Diapers tabs, the entries themselves
/// live in `_FeedingHomeState` (which also feeds the Home card), so this page
/// only renders them and reports edits/deletes back up. The "Add
/// Measurement" button is the main scaffold's FAB.
class GrowthPage extends StatefulWidget {
  const GrowthPage({
    super.key,
    required this.entries,
    required this.onEdit,
    required this.onDelete,
  });

  final List<GrowthEntry> entries;
  final void Function(GrowthEntry entry) onEdit;
  final void Function(GrowthEntry entry) onDelete;

  @override
  State<GrowthPage> createState() => _GrowthPageState();
}

class _GrowthPageState extends State<GrowthPage> {
  GrowthMetric _metric = GrowthMetric.weight;
  // Unlike Feedings/Diapers, growth measurements are logged rarely (weekly
  // or monthly, not several times a day), so a "recent window" default would
  // often show an empty screen — default to all time instead.
  DateTimeRange? _filterRange;

  List<GrowthEntry> get _filteredEntries {
    final range = _filterRange;
    if (range == null) return List.of(widget.entries);
    return filterEntriesForRange(widget.entries, range);
  }

  String _formatMeasurement(GrowthEntry entry) {
    final parts = [
      if (entry.weight != null) 'Weight: ${entry.weight} ${entry.weightUnit}',
      if (entry.height != null) 'Height: ${entry.height} ${entry.heightUnit}',
    ];
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SegmentedButton<GrowthMetric>(
                  segments: const [
                    ButtonSegment(value: GrowthMetric.weight, label: Text('Weight')),
                    ButtonSegment(value: GrowthMetric.height, label: Text('Height')),
                  ],
                  selected: {_metric},
                  onSelectionChanged: (selection) => setState(() => _metric = selection.first),
                ),
              ),
              DateRangeFilterBar(
                range: _filterRange,
                onChanged: (range) => setState(() => _filterRange = range),
              ),
              if (entries.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: SizedBox(
                    height: 220,
                    child: GrowthChart(entries: entries, metric: _metric),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
              ],
            ],
          ),
        ),
        if (entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: _filterRange == null ? Icons.monitor_weight : Icons.search,
              message: _filterRange == null
                  ? 'No measurements yet!\nTap Add Measurement to record one.'
                  : 'No measurements found for ${formatFilterRange(_filterRange!)}.',
            ),
          )
        else
          _buildGroupedSliver(entries),
      ],
    );
  }

  /// Measurements bucketed under a header per calendar day, newest day
  /// first, mirroring the Feedings/Diapers tabs' grouped-list pattern.
  Widget _buildGroupedSliver(List<GrowthEntry> entries) {
    final items = <Object>[];
    for (final day in groupEntriesByDay(entries)) {
      items.add(day);
      items.addAll(day.entries);
    }

    return SliverPadding(
      // Extra bottom padding keeps the last card clear of the floating
      // "Add Measurement" button, which would otherwise sit on top of it.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];
            if (item is GrowthEntry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildTile(item),
              );
            }
            return _buildDayHeader(item as EntryDay<GrowthEntry>, isFirst: index == 0);
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildDayHeader(EntryDay<GrowthEntry> group, {required bool isFirst}) {
    final count = group.entries.length;
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 8, bottom: 8, left: 4),
      child: Text(
        '${DateFormat.yMMMd().format(group.day)} · $count ${count == 1 ? 'measurement' : 'measurements'}',
        style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTile(GrowthEntry entry) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
          child: const Icon(Icons.monitor_weight),
        ),
        title: Text(
          _formatMeasurement(entry),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat.jm().format(entry.time)),
            if (entry.notes.isNotEmpty) Text(entry.notes),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => widget.onEdit(entry),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => widget.onDelete(entry),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}
