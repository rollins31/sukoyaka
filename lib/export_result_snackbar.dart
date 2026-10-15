import 'package:flutter/material.dart';

import 'pdf_export.dart';

/// Runs a history tab's PDF export and shows a snackbar for the outcomes that
/// need one. A successful share or a share sheet the user backed out of
/// already got their own feedback from the OS, so only the empty-data and
/// failure cases need a message from us.
Future<void> exportWithFeedback(
  BuildContext context, {
  required Future<ReportExportResult> Function() export,
  required String noDataMessage,
}) async {
  void show(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  try {
    switch (await export()) {
      case ReportExportResult.noData:
        show(noDataMessage);
      case ReportExportResult.unavailable:
        show('Sharing isn\'t available on this device.');
      case ReportExportResult.shared:
      case ReportExportResult.cancelled:
        break;
    }
  } catch (_) {
    show('Couldn\'t export PDF. Please try again.');
  }
}
