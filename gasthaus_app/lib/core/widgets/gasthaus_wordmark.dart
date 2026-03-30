import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

// A reusable brand widget showing the Gasthaus logo and optional tagline.
//
// Extracted into its own widget (rather than copy-pasting markup into every
// screen) so there is a single source of truth for brand presentation.
// In Flutter, any UI that appears in more than one place should become a widget.
class GasthausWordmark extends StatelessWidget {
  // Optional tagline rendered below the brand name in muted text.
  // Making it nullable lets callers omit it when context doesn't need it.
  final String? tagline;

  const GasthausWordmark({super.key, this.tagline});

  @override
  Widget build(BuildContext context) {
    // Column lays out children vertically, which is what we want:
    // icon + name on one row, tagline below.
    return Column(
      // mainAxisSize.min means the Column only takes as much vertical space
      // as its children need — it doesn't stretch to fill its parent.
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row for the icon and brand name side-by-side.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The restaurant icon in amber — matches the stitch design.
            // Icons.restaurant is from Flutter's built-in Material icon set.
            const Icon(
              Icons.restaurant,
              color: AppColors.primary, // #D97706 amber
              size: 28,
            ),
            const SizedBox(width: 8),

            // Brand name in all-caps with wide letter-spacing.
            // GoogleFonts.inter() returns a TextStyle — we pass it directly
            // rather than using a named style because this specific combination
            // (extrabold, tracked, uppercase) is only used here.
            Text(
              'GASTHAUS',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 18 * 0.3, // 0.3em → multiply by font size
              ),
            ),
          ],
        ),

        // Only render the tagline if one was provided.
        // The `...` (spread operator) + `if` pattern is idiomatic Flutter
        // for conditionally including widgets inside a list literal.
        if (tagline != null) ...[
          const SizedBox(height: 6),
          Text(
            tagline!,
            // The `!` asserts non-null — safe here because we checked above.
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted, // #9CA3AF
            ),
          ),
        ],
      ],
    );
  }
}
