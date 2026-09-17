import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'feeding_entry.dart';

const milkTypes = ['Bottle', 'Breastfeeding', 'Other'];
const amountUnits = ['ml', 'oz'];

/// Sequential date-then-time picker shared by the feeding, sleep and diaper
/// forms. Returns null if the user backs out of either step, so the caller
/// leaves its current value untouched. [context] should be the dialog's own
/// context.
Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 365)),
    lastDate: DateTime.now().add(const Duration(days: 365)),
  );
  if (date == null) return null;
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

Future<FeedingEntry?> showFeedingEntryForm(BuildContext context, {FeedingEntry? existingEntry}) async {
  final milkType = ValueNotifier<String>(existingEntry?.milkType ?? milkTypes[0]);
  final amountUnit = ValueNotifier<String>(existingEntry?.amountUnit ?? amountUnits[0]);
  final amountController = TextEditingController(
    text: existingEntry?.amount != null ? existingEntry!.amount!.toString() : '',
  );
  final notesController = TextEditingController(text: existingEntry?.notes ?? '');
  DateTime selectedDate = existingEntry?.time ?? DateTime.now();

  final formKey = GlobalKey<FormState>();

  final result = await showDialog<FeedingEntry>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existingEntry == null ? 'Record Feeding' : 'Edit Feeding'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: milkType,
                      builder: (context, value, child) {
                        return DropdownButtonFormField<String>(
                          initialValue: value,
                          decoration: const InputDecoration(labelText: 'Milk type'),
                          items: milkTypes
                              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                              .toList(),
                          onChanged: (selected) {
                            if (selected != null) milkType.value = selected;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: amountController,
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              hintText: 'e.g. 120',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) return null;
                              final parsed = double.tryParse(value);
                              if (parsed == null || parsed < 0) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: ValueListenableBuilder<String>(
                            valueListenable: amountUnit,
                            builder: (context, value, child) {
                              return DropdownButtonFormField<String>(
                                initialValue: value,
                                decoration: const InputDecoration(labelText: 'Unit'),
                                items: amountUnits
                                    .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                                    .toList(),
                                onChanged: (selected) {
                                  if (selected != null) amountUnit.value = selected;
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
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
                        final picked = await pickDateTime(context, selectedDate);
                        if (picked == null) return;
                        setDialogState(() => selectedDate = picked);
                      },
                      child: Text('Set date/time: ${DateFormat.yMMMd().add_jm().format(selectedDate)}'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final amount = amountController.text.isEmpty ? null : double.tryParse(amountController.text);
                  final entry = FeedingEntry(
                    id: existingEntry?.id ?? DateTime.now().millisecondsSinceEpoch,
                    time: selectedDate,
                    milkType: milkType.value,
                    amount: amount,
                    amountUnit: amountUnit.value,
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
