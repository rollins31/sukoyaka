import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_store.dart';
import 'app_theme.dart';
import 'backup_data.dart';
import 'backup_service.dart';
import 'date_range_filter_bar.dart';
import 'export_result_snackbar.dart';
import 'home_layout_screen.dart';
import 'pdf_export.dart';
import 'privacy_policy_screen.dart';
import 'section_title.dart';

/// Settings screen: appearance, Home layout, backup/restore, PDF reports and
/// app info. Pops itself after a successful restore.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

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

  AppStore get _store => widget.store;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await shareBackup(_store.toBackup());
    } catch (_) {
      _showError('Couldn\'t export backup. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    AppBackup? backup;
    setState(() => _busy = true);
    try {
      backup = await pickAndParseBackup();
    } on FormatException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Couldn\'t read that backup file. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (backup == null || !mounted) return;

    final confirmed = await _confirmRestore(backup);
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await _store.restore(backup);
    if (!mounted) return;
    // The messenger outlives this route, so the message stays up on Home.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup restored.')),
    );
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
    final picked = await pickDateRange(context, _reportRange);
    if (picked == null) return;
    setState(() => _reportRange = picked);
  }

  Future<void> _exportPdf() async {
    setState(() => _busy = true);
    await exportWithFeedback(
      context,
      export: () => exportReportToPdf(
        sections: _reportSections,
        range: _reportRange,
        feedings: _store.feedings,
        sleepEntries: _store.sleeps,
        diaperEntries: _store.diapers,
        growthEntries: _store.growth,
      ),
      noDataMessage: 'No records found for the selected type(s) and range.',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final mutedStyle = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            children: [
              const SectionTitle(Icons.brightness_medium, 'Appearance'),
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
          const SizedBox(height: 16),
          SectionCard(
            children: [
              const SectionTitle(Icons.dashboard_customize, 'Home page'),
              const SizedBox(height: 8),
              Text('Choose which category cards appear on the Home page and in what order.', style: mutedStyle),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const HomeLayoutScreen()),
                ),
                icon: const Icon(Icons.reorder),
                label: const Text('Customize home page'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SectionCard(
            children: [
              const SectionTitle(Icons.save, 'Backup & restore'),
              const SizedBox(height: 8),
              // Counts can change while this screen is open, e.g. when the app
              // resumes after a widget quick-log.
              ListenableBuilder(
                listenable: _store,
                builder: (context, _) => Text(_recordSummary(), style: mutedStyle),
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
          const SizedBox(height: 16),
          SectionCard(
            children: [
              const SectionTitle(Icons.picture_as_pdf, 'PDF report'),
              const SizedBox(height: 12),
              Text('Include:', style: mutedStyle),
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
          const SizedBox(height: 16),
          SectionCard(
            children: [
              const SectionTitle(Icons.info_outline, 'About'),
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: const Text('Open-source licenses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(context: context, applicationName: 'Sukoyaka'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "On this device: 7 records (1 feedings, 3 sleep sessions, …)."
  String _recordSummary() {
    final feedings = _store.feedings.length;
    final sleeps = _store.sleeps.length;
    final diapers = _store.diapers.length;
    final growth = _store.growth.length;
    final total = feedings + sleeps + diapers + growth;
    return 'On this device: $total record${total == 1 ? '' : 's'} '
        '($feedings feedings, $sleeps sleep sessions, $diapers diaper '
        'changes, $growth growth measurements).';
  }

  String _labelFor(ReportSection section) => switch (section) {
        ReportSection.feedings => 'Feedings',
        ReportSection.sleep => 'Sleep',
        ReportSection.diapers => 'Diapers',
        ReportSection.growth => 'Growth',
      };
}
