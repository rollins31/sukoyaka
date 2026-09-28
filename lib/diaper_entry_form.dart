import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'diaper_entry.dart';
import 'feeding_entry_form.dart' show pickDateTime;

Future<DiaperEntry?> showDiaperEntryForm(BuildContext context, {DiaperEntry? existingEntry}) async {
  final notesController = TextEditingController(text: existingEntry?.notes ?? '');
  bool pee = existingEntry?.pee ?? false;
  bool poo = existingEntry?.poo ?? false;
  DateTime time = existingEntry?.time ?? DateTime.now();

  final result = await showDialog<DiaperEntry>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existingEntry == null ? 'Record Diaper Change' : 'Edit Diaper Change'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pee'),
                    value: pee,
                    onChanged: (value) => setDialogState(() => pee = value ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Poo'),
                    value: poo,
                    onChanged: (value) => setDialogState(() => poo = value ?? false),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Leave both unchecked for a dry diaper change.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Extra notes',
                      hintText: 'Optional details',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await pickDateTime(context, time);
                      if (picked == null) return;
                      setDialogState(() => time = picked);
                    },
                    child: Text('Set date/time: ${DateFormat.yMMMd().add_jm().format(time)}'),
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
                onPressed: () {
                  final entry = DiaperEntry(
                    id: existingEntry?.id ?? DateTime.now().millisecondsSinceEpoch,
                    time: time,
                    pee: pee,
                    poo: poo,
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
