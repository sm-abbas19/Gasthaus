import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/menu_item.dart';
import '../../../core/theme/app_colors.dart';

// MenuItemCard renders a single item in the 2-column grid.
//
// It's a StatelessWidget because it holds no mutable state — all data comes
// in through constructor parameters (item, onTap, onAdd). This makes it
// easy to reuse and test: pass different items, get different cards.
class MenuItemCard extends StatelessWidget {
  final MenuItem item;

  // Callbacks use VoidCallback (a typedef for `void Function()`).
  // By accepting callbacks rather than navigating directly, the card stays
  // "dumb" — it doesn't know or care about routing or cart logic.
  // The parent (MenuScreen) decides what to do.
  final VoidCallback onTap; // opens ItemDetailSheet
  final VoidCallback onAdd; // quick-add 1 unit to cart

  const MenuItemCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    // GestureDetector wraps the whole card to detect taps (opens detail sheet).
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        // clipBehavior clips the food image to the card's rounded corners.
        // Without it, the image would bleed outside the border radius.
        clipBehavior: Clip.hardEdge,
        child: Stack(
          // Stack lets us layer the "+" button on top of the card content.
          // Children are drawn back to front — last child is on top.
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImage(),
                _buildTextArea(),
              ],
            ),

            // "+" button pinned to bottom-right using Positioned.
            // Positioned only works inside a Stack.
            Positioned(
              bottom: 10,
              right: 10,
              child: _AddButton(
                available: item.available,
                onTap: item.available ? onAdd : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    // AspectRatio enforces a 4:3 image regardless of the card's actual width.
    // This keeps the grid uniform even if images have different native sizes.
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // CachedNetworkImage downloads the image once and caches it to disk.
          // Future scrolls show the cached version instantly.
          // This is essential for list/grid views with many images.
          if (item.imageUrl != null)
            CachedNetworkImage(
              imageUrl: item.imageUrl!,
              fit: BoxFit.cover,
              // Placeholder shown while downloading
              placeholder: (_, _) => Container(color: AppColors.divider),
              // Error widget shown if the image fails to load
              errorWidget: (_, _, _) => _ImageFallback(),
            )
          else
            _ImageFallback(),

          // Availability badge overlaid on top-left of the image
          Positioned(
            top: 8,
            left: 8,
            child: _AvailabilityBadge(available: item.available),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea() {
    // Right padding of 40 reserves space for the "+" button below.
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 40, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            maxLines: 1,
            // TextOverflow.ellipsis truncates with "..." if the name is too long.
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            // NumberFormat('#,##0') formats 1200 as "1,200" using locale-aware
            // thousand separators. The intl package is Flutter's standard for
            // number and date formatting.
            'Rs. ${NumberFormat('#,##0').format(item.price.round())}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// Private helper widgets — the underscore prefix means they're only accessible
// within this file. This is a Dart visibility mechanism (no private keyword).

class _ImageFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.divider,
      child: const Center(
        child: Icon(Icons.restaurant, color: AppColors.textMuted, size: 32),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  final bool available;
  const _AvailabilityBadge({required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // withValues(alpha:) adjusts opacity. 0.93 ≈ 93% opaque.
        // Available → green tint; Out of Stock → red tint (matches error palette).
      color: available
            ? AppColors.successLight.withValues(alpha: 0.93)
            : AppColors.errorLight.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        available ? 'Available' : 'Out of Stock',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: available ? AppColors.success : AppColors.error,
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final bool available;
  final VoidCallback? onTap;
  const _AddButton({required this.available, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // onTap: null disables the gesture detector (no visual or functional response)
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: available ? AppColors.primary : AppColors.border,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.add,
          size: 18,
          color: available ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }
}
