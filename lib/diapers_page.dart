import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'app_store.dart';
import 'date_range_filter_bar.dart';
import 'diaper_entry.dart';
import 'empty_state.dart';
import 'entry_actions.dart';
import 'export_result_snackbar.dart';
import 'feeding_filters.dart';
import 'pdf_export.dart';

/// The Diapers tab: a date-filtered history grouped by day. The "Record
/// Change" button is the main scaffold's FAB.
class DiapersPage extends StatefulWidget {
  const DiapersPage({super.key, required this.store});

  final AppStore store;

  @override
  State<DiapersPage> createState() => _DiapersPageState();
}

class _DiapersPageState extends State<DiapersPage> {
  DateTimeRange? _filterRange = lastSevenDays();

  AppStore get _store => widget.store;

  Future<void> _exportSelectedRange() async {
    if (_store.diapers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no diaper changes to export.')),
      );
      return;
    }

    final selectedRange = _filterRange ?? await pickDateRange(context, null);
    if (selectedRange == null || !mounted) return;

    await exportWithFeedback(
      context,
      export: () => exportReportToPdf(
        sections: {ReportSection.diapers},
        range: selectedRange,
        diaperEntries: _store.diapers,
      ),
      noDataMessage: 'No diaper changes were found for the selected range.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _filterRange;
    final entries = range == null ? List.of(_store.diapers) : filterEntriesForRange(_store.diapers, range);
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
                  icon: range == null ? Icons.baby_changing_station : Icons.search,
                  message: range == null
                      ? 'No diaper changes yet!\nTap Record Change to add one.'
                      : 'No records found for ${formatFilterRange(range)}.',
                )
              : _buildGroupedList(entries),
        ),
      ],
    );
  }

  /// Diaper changes bucketed under a header per calendar day, newest day first.
  /// Rows show only the time of day because the header carries the date.
  Widget _buildGroupedList(List<DiaperEntry> entries) {
    // Flattened so the list stays lazily built: each item is either an
    // EntryDay header or one of that day's entries.
    final items = <Object>[];
    for (final day in groupEntriesByDay(entries)) {
      items.add(day);
      items.addAll(day.entries);
    }

    return ListView.builder(
      // Extra bottom padding keeps the last card clear of the floating
      // "Record Change" button, which would otherwise sit on top of it.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is DiaperEntry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTile(item),
          );
        }
        return _buildDayHeader(item as EntryDay<DiaperEntry>, isFirst: index == 0);
      },
    );
  }

  Widget _buildDayHeader(EntryDay<DiaperEntry> group, {required bool isFirst}) {
    final count = group.entries.length;
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 8, bottom: 8, left: 4),
      child: Text(
        '${DateFormat.yMMMd().format(group.day)} · $count ${count == 1 ? 'change' : 'changes'}',
        style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTile(DiaperEntry entry) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
          child: const Icon(Icons.baby_changing_station),
        ),
        title: Text(
          entry.contentsLabel,
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
              onPressed: () => editDiaper(context, _store, entry),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _store.deleteDiaper(entry),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}
