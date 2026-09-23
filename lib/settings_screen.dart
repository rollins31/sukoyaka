import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'backup_data.dart';
import 'backup_service.dart';
import 'diaper_entry.dart';
import 'feeding_entry.dart';
import 'growth_entry.dart';
import 'main.dart' show themeModeNotifier, setThemeMode;
import 'pdf_export.dart';
import 'privacy_policy_screen.dart';
import 'sleep_entry.dart';

/// Settings screen: appearance, backup/restore, and PDF reports.
/// [onRestore] is expected to replace the app's stored data, persist it, and
/// reschedule reminders; this screen pops itself once that finishes.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.feedings,
    required this.sleepEntries,
    required this.diaperEntries,
    required this.growthEntries,
    required this.reminderInterval,
    required this.diaperReminderEnabled,
    required this.diaperReminderInterval,
    required this.onRestore,
  });

  final List<FeedingEntry> feedings;
  final List<SleepEntry> sleepEntries;
  final List<DiaperEntry> diaperEntries;
  final List<GrowthEntry> growthEntries;
  final Duration reminderInterval;
  final bool diaperReminderEnabled;
  final Duration diaperReminderInterval;
  final Future<void> Function(AppBackup backup) onRestore;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  final Set<ReportSection> _reportSections = {
    ReportSection.feedings,
    ReportSection.sleep,
    ReportSection.diapers,
    ReportSection.growth,
  };
  DateTimeRange? _reportRange;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final backup = AppBackup(
        exportedAt: DateTime.now(),
        feedings: widget.feedings,
        sleepEntries: widget.sleepEntries,
        diaperEntries: widget.diaperEntries,
        growthEntries: widget.growthEntries,
        reminderIntervalMinutes: widget.reminderInterval.inMinutes,
        diaperReminderEnabled: widget.diaperReminderEnabled,
        diaperReminderIntervalMinutes: widget.diaperReminderInterval.inMinutes,
      );
      await shareBackup(backup);
    } catch (e) {
      _showError('Couldn\'t export backup: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    AppBackup? backup;
    setState(() => _busy = true);
    try {
      backup = await pickAndParseBackup();
    } catch (e) {
      _showError('Couldn\'t read that backup file: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (backup == null || !mounted) return;

    final confirmed = await _confirmRestore(backup);
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await widget.onRestore(backup);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<bool?> _confirmRestore(AppBackup backup) {
    final count = backup.entryCount;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'This backup has $count record${count == 1 ? '' : 's'} '
          'from ${DateFormat.yMMMd().add_jm().format(backup.exportedAt)}.\n\n'
          'Restoring will replace all feedings, sleep sessions, diaper '
          'changes, and growth measurements currently on this device. '
          'This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace my data'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickReportRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _reportRange,
    );
    if (picked == null) return;
    setState(() => _reportRange = picked);
  }

  Future<void> _exportPdf() async {
    setState(() => _busy = true);
    try {
      final result = await exportReportToPdf(
        sections: _reportSections,
        range: _reportRange,
        feedings: widget.feedings,
        sleepEntries: widget.sleepEntries,
        diaperEntries: widget.diaperEntries,
        growthEntries: widget.growthEntries,
      );
      if (!mounted) return;
      // A successful share or one the user backed out of already got its own
      // feedback from the OS share sheet; only the other outcomes need ours.
      switch (result) {
        case ReportExportResult.noData:
          _showError('No records found for the selected type(s) and range.');
        case ReportExportResult.unavailable:
          _showError('Sharing isn\'t available on this device.');
        case ReportExportResult.shared:
        case ReportExportResult.cancelled:
          break;
      }
    } catch (e) {
      _showError('Couldn\'t export PDF: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedingCount = widget.feedings.length;
    final sleepCount = widget.sleepEntries.length;
    final diaperCount = widget.diaperEntries.length;
    final growthCount = widget.growthEntries.length;
    final totalCount = feedingCount + sleepCount + diaperCount + growthCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.brightness_medium, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Appearance',
                        style: GoogleFonts.baloo2(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeModeNotifier,
                    builder: (context, mode, _) {
                      return SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: FittedBox(fit: BoxFit.scaleDown, child: Text('System')),
                            icon: Icon(Icons.brightness_auto),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: FittedBox(fit: BoxFit.scaleDown, child: Text('Light')),
                            icon: Icon(Icons.light_mode),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: FittedBox(fit: BoxFit.scaleDown, child: Text('Dark')),
                            icon: Icon(Icons.dark_mode),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (selection) => setThemeMode(selection.first),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.save, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Backup & restore',
                        style: GoogleFonts.baloo2(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'On this device: $totalCount record${totalCount == 1 ? '' : 's'} '
                    '($feedingCount feedings, $sleepCount sleep sessions, $diaperCount diaper '
                    'changes, $growthCount growth measurements).',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _export,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Export backup'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _import,
                    icon: const Icon(Icons.file_open),
                    label: const Text('Restore from backup'),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.picture_as_pdf, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'PDF report',
                        style: GoogleFonts.baloo2(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Include:',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final section in ReportSection.values)
                        FilterChip(
                          label: Text(_labelFor(section)),
                          selected: _reportSections.contains(section),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _reportSections.add(section);
                            } else {
                              _reportSections.remove(section);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickReportRange,
                          icon: const Icon(Icons.date_range),
                          label: Text(_reportRange == null ? 'All time' : formatDateRange(_reportRange!)),
                        ),
                      ),
                      if (_reportRange != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => setState(() => _reportRange = null),
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear (use all time)',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: (_busy || _reportSections.isEmpty) ? null : _exportPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF report'),
                  ),
                  if (_reportSections.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Pick at least one type to include.',
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                    ),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'About',
                        style: GoogleFonts.baloo2(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(ReportSection section) => switch (section) {
        ReportSection.feedings => 'Feedings',
        ReportSection.sleep => 'Sleep',
        ReportSection.diapers => 'Diapers',
        ReportSection.growth => 'Growth',
      };
}
