import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_data.dart';

/// Opens the platform share sheet with the current data as a `.json` file,
/// so the user can save it to Drive/Files/email/another device.
Future<void> shareBackup(AppBackup backup) async {
  final fileName = 'sukoyaka_backup_${DateTime.now().millisecondsSinceEpoch}.json';
  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(backup.toJson())));
  final file = XFile.fromData(bytes, name: fileName, mimeType: 'application/json');
  await SharePlus.instance.share(
    ShareParams(
      files: [file],
      fileNameOverrides: [fileName],
      subject: 'Sukoyaka backup',
    ),
  );
}

/// Lets the user pick a `.json` backup file and parses it.
///
/// Returns `null` if the user cancelled the picker. Throws [FormatException]
/// if the file isn't valid backup JSON.
Future<AppBackup?> pickAndParseBackup() async {
  final picked = await FilePicker.pickFile(
    dialogTitle: 'Choose a Sukoyaka backup file',
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('That file doesn\'t look like a Sukoyaka backup.');
  }
  return AppBackup.fromJson(decoded);
}
