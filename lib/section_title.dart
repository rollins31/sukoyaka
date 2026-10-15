import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Icon plus heading used for each section of the Home cards.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.icon, this.text, {super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.baloo2(fontSize: 19, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}
