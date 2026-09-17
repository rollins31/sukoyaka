import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Static privacy policy text, shown in-app under Settings. This is the
/// canonical copy — also published at https://rollins31.github.io/sukoyaka/
/// (docs/index.html) for the App Store / Play Store listing forms. Keep
/// both copies in sync when editing.
const _effectiveDate = 'September 15, 2026';

const _sections = <(String, String)>[
  (
    'Data storage',
    'All records you enter (feedings, sleep sessions, diaper changes, growth '
        'measurements) are stored locally on your device only. Nothing you log '
        'is sent to us or to any server we operate — there is no account, no '
        'sign-in, and no cloud sync.',
  ),
  (
    'Notifications',
    'Feeding and diaper reminders are scheduled directly on your device using '
        'your operating system\'s notification system. No reminder data leaves '
        'your device.',
  ),
  (
    'Home screen widget',
    'If you use the home-screen widget, it reads and writes the same on-device '
        'data described above to show your last feeding and next reminder. This '
        'data does not leave your device.',
  ),
  (
    'Backup, restore, and reports',
    'You can export your data as a backup file or a PDF report. These exports '
        'are created on your device and only leave it when you choose to share '
        'or save them — for example, by sending them to your own email, saving '
        'to your files, or sharing with your baby\'s other caregivers. You '
        'control where this data goes; we do not receive a copy.',
  ),
  (
    'Fonts',
    'The app loads its typefaces using Google\'s font service, which may make '
        'a network request to Google\'s servers to fetch font files. This '
        'request can include your device\'s IP address, as with any network '
        'request, but does not include any of your baby-tracking data.',
  ),
  (
    'Children\'s privacy',
    'Sukoyaka is intended to be used by parents and caregivers to track '
        'information about a child, not to be used directly by children. We do '
        'not knowingly collect any information from children through the app.',
  ),
  (
    'Data you control',
    'Because all your data is stored locally, you can delete it at any time by '
        'clearing the app\'s data or uninstalling the app. There is no account '
        'for us to delete on your behalf, because none exists.',
  ),
  (
    'Changes to this policy',
    'If this policy changes, we\'ll update the effective date above.',
  ),
  (
    'Contact',
    'Questions about this policy can be sent to rollins31@gmail.com.',
  ),
];

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headingStyle = GoogleFonts.baloo2(fontSize: 17, fontWeight: FontWeight.w700, color: colorScheme.primary);
    final bodyStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sukoyaka is designed to help you track your baby\'s feedings, sleep, '
              'diaper changes, and growth. This page explains what data the app '
              'handles and how.',
              style: bodyStyle,
            ),
            const SizedBox(height: 4),
            Text('Effective $_effectiveDate', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
            for (final (heading, body) in _sections) ...[
              const SizedBox(height: 20),
              Text(heading, style: headingStyle),
              const SizedBox(height: 6),
              Text(body, style: bodyStyle),
            ],
          ],
        ),
      ),
    );
  }
}
