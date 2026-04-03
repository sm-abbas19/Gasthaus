import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/menu_item.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../cart/cart_provider.dart';

// Convenience function to open the sheet from anywhere.
// Calling showModalBottomSheet here instead of in the screen keeps the
// call site clean: just `showItemDetail(context, item)`.
//
// isScrollControlled: true — by default, bottom sheets are limited to 50%
// of the screen height. This flag removes that limit so our tall sheet fits.
//
// backgroundColor: Colors.transparent — we want the sheet itself to handle
// its own background (rounded corners). If we leave the default opaque color,
// the sheet container clips our rounded-corner decoration.
void showItemDetail(BuildContext context, MenuItem item) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    // enableDrag: true lets the user swipe the sheet down to dismiss.
    // Flutter resolves the conflict between sheet drag and scroll naturally:
    // when the scroll is at the top a downward gesture dismisses the sheet;
    // otherwise it scrolls. This is the standard modal sheet behaviour on both
    // iOS and Android — the drag handle at the top provides a clear affordance.
    enableDrag: true,
    builder: (_) => ItemDetailSheet(item: item),
  );
}

// ItemDetailSheet is StatefulWidget because it owns mutable local state:
// quantity counter, description expansion toggle, and the AI summary fetch.
class ItemDetailSheet extends StatefulWidget {
  final MenuItem item;
  const ItemDetailSheet({super.key, required this.item});

  @override
  State<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends State<ItemDetailSheet> {
  int _quantity = 1;
  bool _expanded = false; // "Read more" toggle for long descriptions
  String? _aiSummary;
  bool _loadingAi = false;

  @override
  void initState() {
    super.initState();
    // initState is the first lifecycle method called after the widget is built.
    // It's called exactly once. Use it to start async work that should happen
    // on widget creation — here, fetching the AI review summary.
    //
    // We DON'T await here because initState is synchronous. The async work
    // runs independently; the widget rebuilds via setState() when it completes.
    _fetchAiSummary();
  }

  Future<void> _fetchAiSummary() async {
    setState(() => _loadingAi = true);
    try {
      final response = await ApiService.instance.dio.post(
        '/ai/review-summary',
        data: {'menuItemId': widget.item.id},
      );
      // The response body might use different keys depending on the backend.
      // We try a few common ones defensively.
      final data = response.data;
      String? summary;
      if (data is Map) {
        summary = (data['summary'] ?? data['text'] ?? data['message'])
            ?.toString();
      }
      // Always check `mounted` before calling setState after an async gap.
      // The user might have closed the sheet before the request completed.
      // Calling setState on a disposed widget throws an error.
      if (mounted) setState(() => _aiSummary = summary);
    } catch (_) {
      // AI summary is an enhancement, not a critical feature.
      // Silently ignore failures — the section just won't appear.
    } finally {
      if (mounted) setState(() => _loadingAi = false);
    }
  }

  void _addToCart() {
    final cart = context.read<CartProvider>();

    // CartProvider.addItem adds 1 unit. If quantity > 1, we update after.
    // This avoids calling notifyListeners multiple times in a loop.
    cart.addItem(widget.item);
    if (_quantity > 1) {
      cart.updateQuantity(widget.item.id, _quantity);
    }

    // Close the sheet — the cart badge updates automatically via CartProvider.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Size the sheet at 88% of screen height to show a sliver of the screen
    // behind it — a UX cue that the content below is still accessible.
    final sheetHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        // Only round the top corners — the bottom is flush with the screen edge.
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle — the small bar that signals this is a draggable sheet.
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Expanded makes this section fill all remaining space between the
          // drag handle and the bottom action bar.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImage(),
                  _buildContent(),
                ],
              ),
            ),
          ),

          // Bottom bar is NOT inside the scroll — it stays pinned at the bottom.
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return SizedBox(
      width: double.infinity,
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.item.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: widget.item.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      Container(color: AppColors.divider),
                  errorWidget: (_, _, _) => Container(
                    color: AppColors.divider,
                    child: const Center(
                      child: Icon(Icons.restaurant,
                          size: 48, color: AppColors.textMuted),
                    ),
                  ),
                )
              : Container(
                  color: AppColors.divider,
                  child: const Center(
                    child: Icon(Icons.restaurant,
                        size: 48, color: AppColors.textMuted),
                  ),
                ),

          // Close button — top-right, white circle with blur background
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    size: 16, color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name
          Text(
            item.name,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 8),

          // Rating row — only shown if the backend provided rating data
          if (item.averageRating != null && item.reviewCount != null) ...[
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  item.averageRating!.toStringAsFixed(1),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${item.reviewCount} reviews)',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Price
          Text(
            'Rs. ${NumberFormat('#,##0').format(item.price.round())}',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),

          const SizedBox(height: 12),

          // Description with optional "Read more" expansion
          _buildDescription(item.description),

          const SizedBox(height: 16),

          // AI summary block (only renders if loading or has content)
          _buildAiSummary(),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDescription(String description) {
    // Only show "Read more" if the text is long enough to be clipped.
    final isLong = description.length > 120;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          // null maxLines means unlimited — used when expanded.
          maxLines: _expanded ? null : 3,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        if (isLong) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Show less' : 'Read more',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAiSummary() {
    // Don't render the block at all if we finished loading and got nothing.
    if (!_loadingAi && _aiSummary == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLighter, // #FFFBEB
        border: Border.all(color: AppColors.primaryBorder), // #FDE68A
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'AI SUMMARY',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 11 * 0.08,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingAi)
            const SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            Text(
              _aiSummary!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final totalPrice = widget.item.price * _quantity;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        // Add bottom padding for the home indicator (iPhone notch, Android gesture bar).
        // MediaQuery.of(context).padding.bottom gives this safe area height.
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Quantity selector: [-] N [+]
          Row(
            children: [
              _QtyButton(
                icon: Icons.remove,
                filled: false,
                // Disable the minus button at quantity 1 (can't go below 1)
                onTap: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
              ),
              SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    '$_quantity',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              _QtyButton(
                icon: Icons.add,
                filled: true,
                onTap: () => setState(() => _quantity++),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // "Add to Cart · Rs. X" button — Expanded makes it fill remaining width
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                // Disable if item is unavailable
                onPressed: widget.item.available ? _addToCart : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Add to Cart'),
                    const SizedBox(width: 6),
                    Text(
                      '·',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                        'Rs. ${NumberFormat('#,##0').format(totalPrice.round())}'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Private quantity button widget used in the bottom bar.
class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap; // null = disabled

  const _QtyButton({
    required this.icon,
    required this.filled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.divider,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: filled
              ? Colors.white
              : (disabled ? AppColors.textMuted : AppColors.textPrimary),
        ),
      ),
    );
  }
}
