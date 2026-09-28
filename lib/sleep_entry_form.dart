import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'feeding_entry_form.dart' show pickDateTime;
import 'sleep_entry.dart';

Future<SleepEntry?> showSleepEntryForm(BuildContext context, {SleepEntry? existingEntry}) async {
  final notesController = TextEditingController(text: existingEntry?.notes ?? '');
  DateTime start = existingEntry?.start ?? DateTime.now();
  DateTime? end = existingEntry?.end;

  final result = await showDialog<SleepEntry>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          String? errorText;
          if (end != null && !end!.isAfter(start)) {
            errorText = 'End must be after start.';
          }
          return AlertDialog(
            title: Text(existingEntry == null ? 'Add Sleep' : 'Edit Sleep'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.bedtime),
                    onPressed: () async {
                      final picked = await pickDateTime(context, start);
                      if (picked == null) return;
                      setDialogState(() => start = picked);
                    },
                    label: Text('Start: ${DateFormat.yMMMd().add_jm().format(start)}'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.wb_sunny),
                    onPressed: () async {
                      final picked = await pickDateTime(context, end ?? start);
                      if (picked == null) return;
                      setDialogState(() => end = picked);
                    },
                    label: Text(end == null
                        ? 'End: still sleeping'
                        : 'End: ${DateFormat.yMMMd().add_jm().format(end!)}'),
                  ),
                  if (end != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setDialogState(() => end = null),
                        child: const Text('Clear end (mark ongoing)'),
                      ),
                    ),
                  if (errorText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      errorText,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Extra notes',
                      hintText: 'Optional details',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: errorText != null
                    ? null
                    : () {
                        final entry = SleepEntry(
                          id: existingEntry?.id ?? DateTime.now().millisecondsSinceEpoch,
                          start: start,
                          end: end,
                          notes: notesController.text.trim(),
                        );
                        Navigator.of(context).pop(entry);
                      },
                child: Text(existingEntry == null ? 'Save' : 'Update'),
              ),
            ],
          );
        },
      );
    },
  );

  return result;
}
