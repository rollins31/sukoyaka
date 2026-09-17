import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'feeding_entry_form.dart' show pickDateTime;
import 'growth_entry.dart';

const weightUnits = ['kg', 'lb'];
const heightUnits = ['cm', 'in'];

Future<GrowthEntry?> showGrowthEntryForm(BuildContext context, {GrowthEntry? existingEntry}) async {
  final weightUnit = ValueNotifier<String>(existingEntry?.weightUnit ?? weightUnits[0]);
  final heightUnit = ValueNotifier<String>(existingEntry?.heightUnit ?? heightUnits[0]);
  final weightController = TextEditingController(
    text: existingEntry?.weight != null ? existingEntry!.weight!.toString() : '',
  );
  final heightController = TextEditingController(
    text: existingEntry?.height != null ? existingEntry!.height!.toString() : '',
  );
  final notesController = TextEditingController(text: existingEntry?.notes ?? '');
  DateTime selectedDate = existingEntry?.time ?? DateTime.now();

  final formKey = GlobalKey<FormState>();

  final result = await showDialog<GrowthEntry>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existingEntry == null ? 'Record Growth' : 'Edit Growth'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: weightController,
                            decoration: const InputDecoration(
                              labelText: 'Weight',
                              hintText: 'e.g. 8.5',
                              errorMaxLines: 2,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return heightController.text.isEmpty ? 'Enter a weight or a height' : null;
                              }
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
                            valueListenable: weightUnit,
                            builder: (context, value, child) {
                              return DropdownButtonFormField<String>(
                                initialValue: value,
                                decoration: const InputDecoration(labelText: 'Unit'),
                                items: weightUnits
                                    .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                                    .toList(),
                                onChanged: (selected) {
                                  if (selected != null) weightUnit.value = selected;
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: heightController,
                            decoration: const InputDecoration(
                              labelText: 'Height / length',
                              hintText: 'e.g. 24.5',
                              errorMaxLines: 2,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return weightController.text.isEmpty ? 'Enter a weight or a height' : null;
                              }
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
                            valueListenable: heightUnit,
                            builder: (context, value, child) {
                              return DropdownButtonFormField<String>(
                                initialValue: value,
                                decoration: const InputDecoration(labelText: 'Unit'),
                                items: heightUnits
                                    .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                                    .toList(),
                                onChanged: (selected) {
                                  if (selected != null) heightUnit.value = selected;
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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final weight = weightController.text.isEmpty ? null : double.tryParse(weightController.text);
                  final height = heightController.text.isEmpty ? null : double.tryParse(heightController.text);
                  final entry = GrowthEntry(
                    id: existingEntry?.id ?? DateTime.now().millisecondsSinceEpoch,
                    time: selectedDate,
                    weight: weight,
                    weightUnit: weightUnit.value,
                    height: height,
                    heightUnit: heightUnit.value,
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
