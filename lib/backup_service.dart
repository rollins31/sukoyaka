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
/// with a message safe to show directly to the user — any lower-level parse
/// error (bad JSON syntax, a missing field, a wrong type) is translated into
/// one plain-language message rather than surfacing the raw exception.
Future<AppBackup?> pickAndParseBackup() async {
  final picked = await FilePicker.pickFile(
    dialogTitle: 'Choose a Sukoyaka backup file',
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (picked == null) return null;

  const notABackupMessage =
      'That file doesn\'t look like a Sukoyaka backup. Choose the .json file '
      'from "Export backup".';

  final Object decoded;
  try {
    final bytes = await picked.readAsBytes();
    decoded = jsonDecode(utf8.decode(bytes));
  } catch (_) {
    throw const FormatException(notABackupMessage);
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(notABackupMessage);
  }

  final version = decoded['version'] as int? ?? 0;
  if (version > backupFormatVersion) {
    throw FormatException(
      'This backup was made by a newer version of the app (format $version) '
      'and can\'t be read here.',
    );
  }

  try {
    return AppBackup.fromJson(decoded);
  } catch (_) {
    throw const FormatException(notABackupMessage);
  }
}
