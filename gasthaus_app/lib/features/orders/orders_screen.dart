import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/models/order.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../reviews/write_review_sheet.dart';
import 'orders_provider.dart';

// OrdersScreen is a StatefulWidget because it needs initState to trigger
// the initial data fetch. A StatelessWidget has no lifecycle hooks —
// you can't call an async method "on first build" without initState.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _dateFmt = DateFormat('MMM d, y • h:mm a');
  final _currencyFmt = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();
    // addPostFrameCallback defers the fetch until after the first frame is drawn.
    // This is necessary because calling a provider method inside initState
    // can trigger setState during build — Flutter forbids that.
    // "Post frame callback" = "after the widget tree has been rendered once".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().fetchOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (context, provider, _) {
        // AnnotatedRegion sets the status bar icons to light (white) while this
        // screen's dark amber top bar is visible — same pattern as menu screen.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                _buildTopBar(),
                _buildFilterChips(provider),
                Expanded(child: _buildBody(provider)),
              ],
            ),
          ),
        );
      },
    );
  }

  // Dark amber top bar matching the menu screen's header style.
  Widget _buildTopBar() {
    return Container(
      color: AppColors.primaryDark,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('My Orders', style: AppTextStyles.topBarTitleLight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(OrdersProvider provider) {
    // The filter chips scroll horizontally so they don't wrap to a second line
    // on narrow devices. SingleChildScrollView + Row achieves this.
    // scrollDirection: Axis.horizontal makes it scroll left/right.
    const filters = [
      ('all', 'All'),
      ('active', 'Active'),
      ('completed', 'Completed'),
      ('cancelled', 'Cancelled'),
    ];

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: filters.map((tuple) {
            final (value, label) = tuple; // Dart 3 record destructuring
            final isSelected = provider.selectedFilter == value;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _FilterChip(
                label: label,
                isSelected: isSelected,
                onTap: () => provider.setFilter(value),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody(OrdersProvider provider) {
    if (provider.isLoading) {
      // Shimmer skeleton list — shows 4 ghost order cards while loading.
      // The shapes mirror a real _OrderCard so the layout is stable.
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => const _OrderCardShimmer(),
      );
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => provider.fetchOrders(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    final orders = provider.filteredOrders;

    if (orders.isEmpty) {
      return _buildEmptyState(provider.selectedFilter);
    }

    // Orders stay current via STOMP WebSocket — no pull-to-refresh needed.
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _OrderCard(
        order: orders[i],
        dateFmt: _dateFmt,
        currencyFmt: _currencyFmt,
        // Provider already knows which orders are reviewed (fetched alongside
        // orders at load time) — no per-tap API call needed.
        isReviewed: provider.isReviewed(orders[i].id),
        onTrack: () => context.push('/orders/${orders[i].id}'),
        onReview: () => _openReviewSheet(context, orders[i]),
      ),
    );
  }

  Widget _buildEmptyState(String filter) {
    final message = filter == 'all'
        ? "You haven't placed any orders yet"
        : "No $filter orders";

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 64, color: AppColors.border),
          const SizedBox(height: 16),
          Text(message,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text('Your order history will appear here',
              style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }

  // Opens the review sheet in write mode.
  // "Leave Review" is only shown when isReviewed == false (checked pre-fetch),
  // so we always open in write mode here. After successful submission,
  // markReviewed() updates the provider so the button disappears immediately.
  void _openReviewSheet(BuildContext context, Order order) {
    showOrderReviewSheet(
      context,
      order: order,
      onReviewed: () {
        // Update provider so the card hides the button without a full re-fetch.
        context.read<OrdersProvider>().markReviewed(order.id);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _OrderCardShimmer — ghost card shown while orders are loading
// ---------------------------------------------------------------------------

class _OrderCardShimmer extends StatelessWidget {
  const _OrderCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.divider,
      highlightColor: AppColors.surface,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order number + status badge row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ShimmerBox(width: 100, height: 14),
                _ShimmerBox(width: 80, height: 22, radius: 99),
              ],
            ),
            const SizedBox(height: 10),
            _ShimmerBox(width: 140, height: 11),
            const SizedBox(height: 14),
            // Thumbnail stack
            Row(
              children: [
                _ShimmerBox(width: 32, height: 32, radius: 8),
                const SizedBox(width: 4),
                _ShimmerBox(width: 32, height: 32, radius: 8),
                const SizedBox(width: 4),
                _ShimmerBox(width: 32, height: 32, radius: 8),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ShimmerBox(width: 40, height: 12),
                _ShimmerBox(width: 70, height: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable grey box for shimmer layouts. Keeps the shimmer widget definitions
// concise — one line per placeholder instead of a full Container each time.
class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FilterChip — a single selectable filter pill
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        // AnimatedContainer smoothly transitions between selected/unselected styles
        // whenever isSelected changes. Duration controls how fast the transition is.
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : AppColors.surface,
          borderRadius: BorderRadius.circular(99),
          border: isSelected
              ? null
              : Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            fontSize: 14,
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _OrderCard — a single order summary card in the list
// ---------------------------------------------------------------------------

class _OrderCard extends StatelessWidget {
  final Order order;
  final DateFormat dateFmt;
  final NumberFormat currencyFmt;
  final bool isReviewed;   // hides "Leave Review" when the order already has one
  final VoidCallback onTrack;
  final VoidCallback onReview;

  const _OrderCard({
    required this.order,
    required this.dateFmt,
    required this.currencyFmt,
    required this.isReviewed,
    required this.onTrack,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap the whole card to navigate to order tracking (except completed orders
      // where the "Leave Review" button occupies the action area).
      onTap: order.isCompleted || order.isCancelled ? null : onTrack,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: order number + status badge (+ "Leave Review" for completed)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // orderNumber is the 8-char uppercase UUID prefix (e.g. "A1B2C3D4")
                        // returned by the Spring Boot @Transient getter, consistent across
                        // all clients.
                        '#${order.orderNumber}',
                        style: AppTextStyles.itemName,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFmt.format(order.createdAt.toLocal()),
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusBadge(status: order.status),
                    // "Leave Review" only shown on COMPLETED orders that haven't
                    // been reviewed yet. isReviewed is pre-computed at fetch time.
                    if (order.isCompleted && !isReviewed) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: onReview,
                        child: Text(
                          'Leave Review',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: thumbnail stack + item count
            Row(
              children: [
                _ThumbnailStack(items: order.items),
                const SizedBox(width: 8),
                Text(
                  '· ${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                ),
                // For active orders, show a subtle "Track →" nudge
                if (order.isActive) ...[
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        'Track',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.primary),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 16, color: AppColors.primary),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Row 3: divider + total
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 13)),
                Text(
                  'Rs. ${currencyFmt.format(order.totalAmount)}',
                  style: AppTextStyles.itemPrice,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StatusBadge — coloured pill showing the order status
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colorsForStatus(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status,
        style: AppTextStyles.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  // Returns (backgroundColour, textColour) for a given status string.
  // Dart 3 records let us return two values without creating a class.
  // Active states use the amber family (brand identity) — escalating from
  // regular amber → dark amber as the order progresses toward READY.
  // Terminal states (SERVED, PAID, COMPLETED, CANCELLED) use grey so they
  // recede visually and the active orders stand out.
  (Color, Color) _colorsForStatus(String s) {
    return switch (s) {
      'PENDING'   => (AppColors.statusPendingBg,   AppColors.statusPendingText),
      'CONFIRMED' => (AppColors.statusConfirmedBg, AppColors.statusConfirmedText),
      'PREPARING' => (AppColors.statusPreparingBg, AppColors.statusPreparingText),
      'READY'     => (AppColors.statusReadyBg,     AppColors.statusReadyText),
      'SERVED'    => (AppColors.statusServedBg,    AppColors.statusServedText),
      'PAID'      => (AppColors.statusCompletedBg, AppColors.statusCompletedText),
      'COMPLETED' => (AppColors.statusCompletedBg, AppColors.statusCompletedText),
      'CANCELLED' => (AppColors.statusCancelledBg, AppColors.statusCancelledText),
      _           => (AppColors.statusPendingBg,   AppColors.statusPendingText),
    };
  }
}

// ---------------------------------------------------------------------------
// _ThumbnailStack — overlapping food image circles (max 3 shown)
// ---------------------------------------------------------------------------

class _ThumbnailStack extends StatelessWidget {
  final List<dynamic> items; // OrderItem list

  const _ThumbnailStack({required this.items});

  @override
  Widget build(BuildContext context) {
    // Show at most 3 thumbnails to keep the row compact.
    final displayItems = items.take(3).toList();
    const size = 32.0;
    const overlap = 10.0; // how many px each thumbnail slides under the previous

    // Stack with Positioned children creates the overlapping effect.
    // Total width = size + (n-1) * (size - overlap)
    final stackWidth = size + (displayItems.length - 1) * (size - overlap);

    return SizedBox(
      width: stackWidth,
      height: size,
      child: Stack(
        children: displayItems.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final imageUrl = item.menuItemImage as String?;

          return Positioned(
            // Each thumbnail is offset left so they overlap from right to left.
            // index 0 is leftmost, index 2 is rightmost.
            left: i * (size - overlap),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                // White border creates the separation illusion between thumbnails
                border: Border.all(color: AppColors.surface, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _fallback(),
                      )
                    : _fallback(),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.divider,
      child: const Icon(Icons.restaurant,
          size: 16, color: AppColors.textMuted),
    );
  }
}
