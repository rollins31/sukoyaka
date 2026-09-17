import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'diaper_entry.dart';
import 'feeding_entry.dart';
import 'feeding_filters.dart';
import 'growth_entry.dart';
import 'sleep_entry.dart';

export 'feeding_filters.dart' show filterEntriesForRange;

/// Which log types a PDF report can include.
enum ReportSection { feedings, sleep, diapers, growth }

/// Result of [exportReportToPdf]: whether there was anything to export, and
/// (when there was) whether the user actually picked a share target.
enum ReportExportResult { noData, shared, cancelled, unavailable }

/// Builds a PDF covering any combination of [sections] and opens the share
/// sheet so the user picks where it goes (an app, email, Save to Files/Drive,
/// etc.) instead of it landing in a fixed, hard-to-find app folder.
///
/// A `null` [range] means "all time" for every included section.
///
/// The actual document layout is CPU-bound synchronous work that can take a
/// while for a large "all time" report, so it runs on a background isolate
/// via [compute] — otherwise it would block the UI isolate and the app would
/// appear to hang with no way to even cancel. Only JSON-safe values are
/// allowed to cross that isolate boundary, so entries go over as their
/// existing `toJson()` maps rather than as live objects.
Future<ReportExportResult> exportReportToPdf({
  required Set<ReportSection> sections,
  required DateTimeRange? range,
  List<FeedingEntry> feedings = const [],
  List<SleepEntry> sleepEntries = const [],
  List<DiaperEntry> diaperEntries = const [],
  List<GrowthEntry> growthEntries = const [],
}) async {
  final request = <String, dynamic>{
    'sections': sections.map((s) => s.name).toList(),
    'rangeStart': range?.start.toIso8601String(),
    'rangeEnd': range?.end.toIso8601String(),
    'feedings': feedings.map((e) => e.toJson()).toList(),
    'sleepEntries': sleepEntries.map((e) => e.toJson()).toList(),
    'diaperEntries': diaperEntries.map((e) => e.toJson()).toList(),
    'growthEntries': growthEntries.map((e) => e.toJson()).toList(),
  };

  final bytes = await compute(_buildReportPdfBytes, request).timeout(
    const Duration(seconds: 30),
    onTimeout: () => throw TimeoutException(
      'PDF generation took too long. Try a narrower date range or fewer types.',
    ),
  );
  if (bytes == null) return ReportExportResult.noData;

  final fileBaseName = sections.length == 1 ? _fileBaseNameFor(sections.first) : 'sukoyaka_report';
  final fileName = '${fileBaseName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
  final title = sections.length == 1 ? _titleFor(sections.first) : 'Sukoyaka Report';

  final result = await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf')],
      fileNameOverrides: [fileName],
      subject: title,
    ),
  );
  return switch (result.status) {
    ShareResultStatus.success => ReportExportResult.shared,
    ShareResultStatus.dismissed => ReportExportResult.cancelled,
    ShareResultStatus.unavailable => ReportExportResult.unavailable,
  };
}

/// Runs on a background isolate (see [exportReportToPdf]) — must stay a
/// top-level function taking a single, JSON-safe argument for [compute].
Future<Uint8List?> _buildReportPdfBytes(Map<String, dynamic> request) async {
  final sections = (request['sections'] as List<dynamic>)
      .map((name) => ReportSection.values.byName(name as String))
      .toSet();
  final rangeStart = request['rangeStart'] as String?;
  final range = rangeStart == null
      ? null
      : DateTimeRange(
          start: DateTime.parse(rangeStart),
          end: DateTime.parse(request['rangeEnd'] as String),
        );

  final feedings = (request['feedings'] as List<dynamic>)
      .map((raw) => FeedingEntry.fromJson(raw as Map<String, dynamic>))
      .toList();
  final sleepEntries = (request['sleepEntries'] as List<dynamic>)
      .map((raw) => SleepEntry.fromJson(raw as Map<String, dynamic>))
      .toList();
  final diaperEntries = (request['diaperEntries'] as List<dynamic>)
      .map((raw) => DiaperEntry.fromJson(raw as Map<String, dynamic>))
      .toList();
  final growthEntries = (request['growthEntries'] as List<dynamic>)
      .map((raw) => GrowthEntry.fromJson(raw as Map<String, dynamic>))
      .toList();

  final filteredFeedings = sections.contains(ReportSection.feedings)
      ? (range == null ? feedings : filterEntriesForRange(feedings, range))
      : const <FeedingEntry>[];
  final filteredSleep = sections.contains(ReportSection.sleep)
      ? _filterSleepForRange(sleepEntries, range)
      : const <SleepEntry>[];
  final filteredDiapers = sections.contains(ReportSection.diapers)
      ? (range == null ? diaperEntries : filterEntriesForRange(diaperEntries, range))
      : const <DiaperEntry>[];
  final filteredGrowth = sections.contains(ReportSection.growth)
      ? (range == null ? growthEntries : filterEntriesForRange(growthEntries, range))
      : const <GrowthEntry>[];

  if (filteredFeedings.isEmpty &&
      filteredSleep.isEmpty &&
      filteredDiapers.isEmpty &&
      filteredGrowth.isEmpty) {
    return null;
  }

  // A base-14 font needs no font file, so it's identical (and safe to
  // construct) on every platform and inside this background isolate.
  final bodyFont = pw.Font.helvetica();
  final dateFormat = DateFormat('MMM d, yyyy HH:mm');
  final title = sections.length == 1 ? _titleFor(sections.first) : 'Sukoyaka Report';

  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text(title, style: pw.TextStyle(font: bodyFont, fontSize: 24)),
        pw.SizedBox(height: 8),
        pw.Text(
          'Range: ${range == null ? 'All time' : formatDateRange(range)}',
          style: pw.TextStyle(font: bodyFont),
        ),
        pw.SizedBox(height: 16),
        if (filteredFeedings.isNotEmpty) ..._feedingSection(filteredFeedings, bodyFont, dateFormat),
        if (filteredSleep.isNotEmpty) ..._sleepSection(filteredSleep, bodyFont, dateFormat),
        if (filteredDiapers.isNotEmpty) ..._diaperSection(filteredDiapers, bodyFont, dateFormat),
        if (filteredGrowth.isNotEmpty) ..._growthSection(filteredGrowth, bodyFont, dateFormat),
      ],
    ),
  );

  return pdf.save();
}

/// 'Aug 3, 2026' for a single day, otherwise 'Jul 28 - Aug 3, 2026'.
String formatDateRange(DateTimeRange range) {
  if (startOfDay(range.start) == startOfDay(range.end)) {
    return DateFormat.yMMMd().format(range.start);
  }
  return '${DateFormat('MMM d').format(range.start)} - ${DateFormat.yMMMd().format(range.end)}';
}

String _titleFor(ReportSection section) => switch (section) {
      ReportSection.feedings => 'Feeding Log',
      ReportSection.sleep => 'Sleep Log',
      ReportSection.diapers => 'Diaper Log',
      ReportSection.growth => 'Growth Log',
    };

String _fileBaseNameFor(ReportSection section) => switch (section) {
      ReportSection.feedings => 'feeding_log',
      ReportSection.sleep => 'sleep_log',
      ReportSection.diapers => 'diaper_log',
      ReportSection.growth => 'growth_log',
    };

/// Sleep sessions don't implement [TimestampedEntry] (they span a range
/// rather than happening at a point in time), so they're matched by start
/// time falling inside [range] instead of reusing [filterEntriesForRange].
List<SleepEntry> _filterSleepForRange(List<SleepEntry> entries, DateTimeRange? range) {
  if (range == null) return entries;
  final start = startOfDay(range.start);
  final end = endOfDay(range.end);
  return entries.where((e) => !e.start.isBefore(start) && !e.start.isAfter(end)).toList();
}

/// Compact "1h 24m" / "8m" duration for the printed report (no seconds —
/// that precision only matters for the live in-app timer).
String _formatReportDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

/// Base-14 PDF fonts only cover Latin-1 (U+0020-U+00FF, plus tab/newline)
/// and throw for anything else — so free-text fields like notes get
/// sanitized before reaching [pw.Text], since a stray emoji shouldn't be
/// able to crash an export.
String _sanitizeForPdf(String input) {
  return String.fromCharCodes(input.runes.map((rune) {
    if (rune == 0x09 || rune == 0x0A) return rune;
    if (rune >= 0x20 && rune <= 0xFF) return rune;
    return 0x3F; // '?'
  }));
}

List<pw.Widget> _feedingSection(List<FeedingEntry> entries, pw.Font font, DateFormat dateFormat) {
  return [
    pw.Text('Feedings', style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 8),
    for (final entry in entries)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(dateFormat.format(entry.time), style: pw.TextStyle(font: font)),
            pw.Text('Milk type: ${_sanitizeForPdf(entry.milkType)}', style: pw.TextStyle(font: font)),
            if (entry.amount != null)
              pw.Text(
                'Amount: ${entry.amount} ${_sanitizeForPdf(entry.amountUnit)}',
                style: pw.TextStyle(font: font),
              ),
            if (entry.notes.isNotEmpty)
              pw.Text('Notes: ${_sanitizeForPdf(entry.notes)}', style: pw.TextStyle(font: font)),
          ],
        ),
      ),
    pw.SizedBox(height: 16),
  ];
}

List<pw.Widget> _sleepSection(List<SleepEntry> entries, pw.Font font, DateFormat dateFormat) {
  return [
    pw.Text('Sleep', style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 8),
    for (final entry in entries)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              entry.isInProgress
                  ? '${dateFormat.format(entry.start)} - ongoing'
                  : '${dateFormat.format(entry.start)} - ${dateFormat.format(entry.end!)} '
                      '(${_formatReportDuration(entry.duration!)})',
              style: pw.TextStyle(font: font),
            ),
            if (entry.notes.isNotEmpty)
              pw.Text('Notes: ${_sanitizeForPdf(entry.notes)}', style: pw.TextStyle(font: font)),
          ],
        ),
      ),
    pw.SizedBox(height: 16),
  ];
}

List<pw.Widget> _diaperSection(List<DiaperEntry> entries, pw.Font font, DateFormat dateFormat) {
  return [
    pw.Text('Diaper changes', style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 8),
    for (final entry in entries)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${dateFormat.format(entry.time)} - ${entry.contentsLabel}', style: pw.TextStyle(font: font)),
            if (entry.notes.isNotEmpty)
              pw.Text('Notes: ${_sanitizeForPdf(entry.notes)}', style: pw.TextStyle(font: font)),
          ],
        ),
      ),
    pw.SizedBox(height: 16),
  ];
}

List<pw.Widget> _growthSection(List<GrowthEntry> entries, pw.Font font, DateFormat dateFormat) {
  return [
    pw.Text('Growth', style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
    pw.SizedBox(height: 8),
    for (final entry in entries)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              [
                dateFormat.format(entry.time),
                if (entry.weight != null) 'Weight: ${entry.weight} ${_sanitizeForPdf(entry.weightUnit)}',
                if (entry.height != null) 'Height: ${entry.height} ${_sanitizeForPdf(entry.heightUnit)}',
              ].join(' - '),
              style: pw.TextStyle(font: font),
            ),
            if (entry.notes.isNotEmpty)
              pw.Text('Notes: ${_sanitizeForPdf(entry.notes)}', style: pw.TextStyle(font: font)),
          ],
        ),
      ),
    pw.SizedBox(height: 16),
  ];
}
