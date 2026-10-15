import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'app_store.dart';
import 'date_range_filter_bar.dart';
import 'empty_state.dart';
import 'entry_actions.dart';
import 'export_result_snackbar.dart';
import 'feeding_entry.dart';
import 'feeding_filters.dart';
import 'pdf_export.dart';

/// The Feedings tab: a date-filtered history grouped by day. The "Record
/// Feeding" button is the main scaffold's FAB.
class FeedingsPage extends StatefulWidget {
  const FeedingsPage({super.key, required this.store});

  final AppStore store;

  @override
  State<FeedingsPage> createState() => _FeedingsPageState();
}

class _FeedingsPageState extends State<FeedingsPage> {
  DateTimeRange? _filterRange = lastSevenDays();

  AppStore get _store => widget.store;

  Future<void> _exportSelectedRange() async {
    if (_store.feedings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no feedings to export.')),
      );
      return;
    }

    // When a range is already on screen, export exactly that instead of asking
    // the user to pick the same dates a second time.
    final selectedRange = _filterRange ?? await pickDateRange(context, null);
    if (selectedRange == null || !mounted) return;

    await exportWithFeedback(
      context,
      export: () => exportReportToPdf(
        sections: {ReportSection.feedings},
        range: selectedRange,
        feedings: _store.feedings,
      ),
      noDataMessage: 'No feedings were found for the selected range.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _filterRange;
    final entries = range == null ? List.of(_store.feedings) : filterEntriesForRange(_store.feedings, range);
    return Column(
      children: [
        DateRangeFilterBar(
          range: range,
          onChanged: (range) => setState(() => _filterRange = range),
          actions: [
            IconButton(
              onPressed: _exportSelectedRange,
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export selected range to PDF',
            ),
          ],
        ),
        Expanded(
          child: entries.isEmpty
              ? EmptyState(
                  icon: range == null ? Icons.local_drink : Icons.search,
                  message: range == null
                      ? 'No feedings yet!\nTap Record Feeding to add one.'
                      : 'No records found for ${formatFilterRange(range)}.',
                )
              : _buildGroupedList(entries),
        ),
      ],
    );
  }

  /// Feedings bucketed under a header per calendar day, newest day first. Rows
  /// show only the time of day because the header carries the date.
  Widget _buildGroupedList(List<FeedingEntry> entries) {
    // Flattened so the list stays lazily built: each item is either a
    // FeedingDay header or one of that day's entries.
    final items = <Object>[];
    for (final day in groupEntriesByDay(entries)) {
      items.add(day);
      items.addAll(day.entries);
    }

    return ListView.builder(
      // Extra bottom padding keeps the last card clear of the floating
      // "Record Feeding" button, which would otherwise sit on top of it.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is FeedingEntry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCard(item),
          );
        }
        return _buildDayHeader(item as FeedingDay, isFirst: index == 0);
      },
    );
  }

  Widget _buildDayHeader(FeedingDay group, {required bool isFirst}) {
    final count = group.entries.length;
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 8, bottom: 8, left: 4),
      child: Text(
        '${DateFormat.yMMMd().format(group.day)} · $count ${count == 1 ? 'feeding' : 'feedings'}',
        style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildCard(FeedingEntry entry) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          child: const Icon(Icons.local_drink),
        ),
        title: Text(
          DateFormat.jm().format(entry.time),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${entry.milkType}${entry.amount != null ? ' • ${entry.amount} ${entry.amountUnit}' : ''}'),
            if (entry.notes.isNotEmpty) Text(entry.notes),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => editFeeding(context, _store, entry),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _store.deleteFeeding(entry),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}
