import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'empty_state.dart';
import 'feeding_filters.dart';
import 'growth_chart.dart';
import 'growth_entry.dart';
import 'growth_entry_form.dart';

const _growthEntriesKey = 'growth_entries';

/// Fully self-contained: growth has no reminders or home-widget sync to
/// coordinate with the rest of the app, so unlike feeding/sleep/diaper this
/// screen owns its own SharedPreferences-backed data rather than being fed
/// state from `_FeedingHomeState`.
class GrowthScreen extends StatefulWidget {
  const GrowthScreen({super.key});

  @override
  State<GrowthScreen> createState() => _GrowthScreenState();
}

class _GrowthScreenState extends State<GrowthScreen> {
  final List<GrowthEntry> _entries = [];
  bool _loading = true;
  GrowthMetric _metric = GrowthMetric.weight;
  // Unlike Feedings/Diapers, growth measurements are logged rarely (weekly
  // or monthly, not several times a day), so a "recent window" default would
  // often show an empty screen — default to all time instead.
  DateTimeRange? _filterRange;

  List<GrowthEntry> get _filteredEntries {
    final range = _filterRange;
    if (range == null) return List.of(_entries);
    return filterEntriesForRange(_entries, range);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_growthEntriesKey);
    final rawEntries = jsonString == null ? [] : jsonDecode(jsonString) as List<dynamic>;
    final loadedEntries = rawEntries
        .map((raw) => GrowthEntry.fromJson(raw as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (!mounted) return;
    setState(() {
      _entries
        ..clear()
        ..addAll(loadedEntries);
      _loading = false;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_growthEntriesKey, encoded);
  }

  Future<void> _add() async {
    final entry = await showGrowthEntryForm(context);
    if (entry == null) return;
    setState(() {
      _entries.add(entry);
      _entries.sort((a, b) => a.time.compareTo(b.time));
    });
    await _save();
  }

  Future<void> _edit(GrowthEntry entry) async {
    final updated = await showGrowthEntryForm(context, existingEntry: entry);
    if (updated == null) return;
    setState(() {
      entry
        ..time = updated.time
        ..weight = updated.weight
        ..weightUnit = updated.weightUnit
        ..height = updated.height
        ..heightUnit = updated.heightUnit
        ..notes = updated.notes;
      _entries.sort((a, b) => a.time.compareTo(b.time));
    });
    await _save();
  }

  Future<void> _delete(GrowthEntry entry) async {
    setState(() {
      _entries.removeWhere((e) => e.id == entry.id);
    });
    await _save();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Growth')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
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
                      _buildFilterBar(),
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
                          : 'No measurements found for ${_formatFilterRange(_filterRange!)}.',
                    ),
                  )
                else
                  _buildGroupedSliver(entries),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add Measurement'),
      ),
    );
  }

  /// The date-range button, quick-filter chips and clear button, mirroring
  /// the filter bar shared by the Feedings and Diapers tabs.
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await _pickDateRange(_filterRange);
                    if (selected == null) return;
                    setState(() => _filterRange = selected);
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _filterRange == null ? 'Filter by date range' : _formatFilterRange(_filterRange!),
                  ),
                ),
              ),
              if (_filterRange != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() => _filterRange = null),
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear filter',
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _filterPresets())
                FilterChip(
                  label: Text(preset.label),
                  selected: _isPresetActive(preset.range, _filterRange),
                  onSelected: (selected) => setState(() => _filterRange = selected ? preset.range : null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shared date-range picker for the filter bar. Returns null when the user
  /// backs out, so the caller leaves the current range untouched.
  Future<DateTimeRange?> _pickDateRange(DateTimeRange? initial) {
    return showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initial,
    );
  }

  /// The quick-filter presets offered above the measurement list. Ranges are
  /// built from bare dates because [filterEntriesForRange] widens them to
  /// whole days.
  List<({String label, DateTimeRange range})> _filterPresets() {
    final today = startOfDay(DateTime.now());
    return [
      (label: 'Today', range: DateTimeRange(start: today, end: today)),
      (
        label: 'Last 7 days',
        range: DateTimeRange(
          start: DateTime(today.year, today.month, today.day - 6),
          end: today,
        ),
      ),
      (
        label: 'This month',
        range: DateTimeRange(
          start: DateTime(today.year, today.month, 1),
          end: today,
        ),
      ),
    ];
  }

  bool _isPresetActive(DateTimeRange preset, DateTimeRange? active) {
    if (active == null) return false;
    return startOfDay(active.start) == preset.start && startOfDay(active.end) == preset.end;
  }

  /// 'Aug 3, 2026' for a single day, otherwise 'Jul 28 - Aug 3, 2026'.
  String _formatFilterRange(DateTimeRange range) {
    if (startOfDay(range.start) == startOfDay(range.end)) {
      return DateFormat.yMMMd().format(range.start);
    }
    return '${DateFormat('MMM d').format(range.start)} - ${DateFormat.yMMMd().format(range.end)}';
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
      padding: const EdgeInsets.all(16),
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
              onPressed: () => _edit(entry),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _delete(entry),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}
