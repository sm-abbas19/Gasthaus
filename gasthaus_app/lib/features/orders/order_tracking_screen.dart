import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/order.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// The 5 statuses shown in the progress stepper, in chronological order.
// Using a top-level const rather than an instance field keeps this data
// class-independent and easy to reference in static helper functions.
const _statusSteps = ['CONFIRMED', 'PREPARING', 'READY', 'SERVED', 'COMPLETED'];
const _stepLabels = ['Confirmed', 'Preparing', 'Ready', 'Served', 'Done'];

// OrderTrackingScreen is a StatefulWidget because it:
//   1. Manages an Order loaded from the API (async state)
//   2. Runs a Timer to poll for status updates (side effect with cleanup)
//   3. Drives a pulsing animation on the status icon (AnimationController lifecycle)
// All three require initState / dispose hooks — which only StatefulWidget has.
class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

// SingleTickerProviderStateMixin gives this State a "vsync" for AnimationController.
// A "ticker" fires a callback every display frame (typically 60/120 Hz).
// The "Single" prefix means this mixin supports exactly one AnimationController —
// use TickerProviderStateMixin (without "Single") if you need multiple controllers.
class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  Order? _order;
  bool _loading = true;
  String? _error;

  // Timer drives periodic polling as a fallback for real-time updates.
  // Phase 8 will layer STOMP WebSocket on top; polling remains as a safety net.
  Timer? _pollTimer;

  // AnimationController owns the animation state — it ticks from 0.0 to 1.0
  // over the given duration, and repeat(reverse: true) bounces it back.
  late final AnimationController _pulseController;

  // Animation<double> is the typed output of the controller passed through a Tween.
  // Tween defines the value range (1.0→1.12 scale). CurvedAnimation shapes the
  // timing (easeInOut = slow-fast-slow, like a heartbeat).
  late final Animation<double> _pulseAnimation;

  final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  void initState() {
    super.initState();

    // Build the pulse animation. Steps:
    //  1. Controller ticks 0.0 → 1.0 over 1500ms, then reverses (1.0 → 0.0), repeat.
    //  2. CurvedAnimation maps that linear 0→1 progress through an easing curve.
    //  3. Tween maps the curved 0→1 to our actual scale values (1.0 → 1.12).
    _pulseController = AnimationController(
      vsync: this, // `this` implements TickerProvider via the mixin
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Fetch immediately on first load, then poll every 10 s.
    _fetchOrder();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchOrder(),
    );
  }

  @override
  void dispose() {
    // Both Timer and AnimationController allocate native resources.
    // Forgetting to cancel/dispose them causes memory leaks and
    // "setState called after dispose" errors in async callbacks.
    _pollTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrder() async {
    try {
      final response =
          await ApiService.instance.dio.get('/orders/${widget.orderId}');
      final order = Order.fromJson(response.data as Map<String, dynamic>);

      // `mounted` is a property on State that returns false after the widget
      // has been removed from the tree. Always check it before calling setState
      // in an async method — the widget may have been popped while the request
      // was in flight.
      if (!mounted) return;

      setState(() {
        _order = order;
        _loading = false;
        _error = null;
      });

      // Stop polling once we reach a terminal status — no further changes possible.
      if (order.isCompleted || order.isCancelled) {
        _pollTimer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      // Only surface the error if we have no previous data to show.
      // If we already have an order, silently fail and keep showing old data —
      // a single failed poll shouldn't wipe out the screen.
      if (_order == null) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    // Show "Order #<number>" in the title, falling back to the raw ID while loading.
    final label = _order?.orderNumber ?? widget.orderId;
    return AppBar(
      // Dark top bar (#1C1C1E) per the stitch design — order tracking feels
      // more focused/premium than the regular white header pattern.
      backgroundColor: AppColors.darkSurface,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        // Go to /orders (the Orders tab) rather than popping, because this screen
        // is navigated to via context.go('/orders/$id') which replaces the stack.
        onPressed: () => context.go('/orders'),
      ),
      title: Text('Order #$label', style: AppTextStyles.topBarTitleLight),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null && _order == null) {
      return _buildErrorState();
    }

    final order = _order!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _buildStatusHeroCard(order),
        const SizedBox(height: 20),
        _buildOrderItemsSection(order),
        const SizedBox(height: 16),
        _buildViewMenuButton(),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 52, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: AppTextStyles.body.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                _fetchOrder();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status hero card: animated icon + title + subtitle + time chip + stepper
  // ---------------------------------------------------------------------------

  Widget _buildStatusHeroCard(Order order) {
    final cfg = _statusConfig(order.status);
    // indexOf returns -1 if status is not in the list (e.g. PENDING, CANCELLED).
    // We treat those as step -1 (nothing highlighted in the stepper).
    final stepIndex = _statusSteps.indexOf(order.status);
    final isTerminal = order.isCompleted || order.isCancelled;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Pulsing icon — ScaleTransition is Flutter's declarative way to
          // animate the scale of a child. It listens to the Animation<double>
          // and rebuilds only the Transform.scale, not the entire tree.
          // AlwaysStoppedAnimation(1.0) is a no-op animation for terminal states.
          ScaleTransition(
            scale: isTerminal
                ? const AlwaysStoppedAnimation(1.0)
                : _pulseAnimation,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cfg.color,
                shape: BoxShape.circle,
              ),
              child: Icon(cfg.icon, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(height: 16),

          Text(cfg.title, style: AppTextStyles.screenTitle),
          const SizedBox(height: 6),
          Text(
            cfg.subtitle,
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),

          // Time chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  cfg.timeLabel,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),

          // Stepper
          const SizedBox(height: 24),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),
          _buildStepper(stepIndex),
        ],
      ),
    );
  }

  // Horizontal 5-step progress indicator.
  // Each step is an Expanded column so they spread evenly across the width.
  // The connecting line between dots is a Divider positioned in the center row —
  // we don't draw it explicitly; instead the row's natural layout gives the illusion.
  Widget _buildStepper(int currentIndex) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_statusSteps.length, (i) {
        final isPast = i < currentIndex;
        final isActive = i == currentIndex;
        final isFuture = i > currentIndex;

        return Expanded(
          child: Column(
            children: [
              // Step dot: filled amber for past/active, hollow for future
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPast || isActive ? AppColors.primary : AppColors.surface,
                  border: Border.all(
                    color: isFuture ? AppColors.border : AppColors.primary,
                    width: 2,
                  ),
                ),
                child: isPast
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : isActive
                        // Active: white dot inside amber circle (ring effect)
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
              ),
              const SizedBox(height: 8),
              Text(
                _stepLabels[i],
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: isPast || isActive
                      ? AppColors.primary
                      : AppColors.textMuted,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Order items section
  // ---------------------------------------------------------------------------

  Widget _buildOrderItemsSection(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('YOUR ORDER', style: AppTextStyles.sectionHeader),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          // ClipRRect ensures children don't bleed outside the rounded corners
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Column(
              children: [
                // Item rows with dividers between them (not after the last)
                ...order.items.asMap().entries.map((entry) {
                  final isLast = entry.key == order.items.length - 1;
                  return Column(
                    children: [
                      _buildItemRow(entry.value),
                      if (!isLast)
                        const Divider(height: 1, color: AppColors.divider),
                    ],
                  );
                }),
                // Total row — slightly tinted background
                Container(
                  color: AppColors.divider,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Rs. ${_fmt.format(order.totalAmount)}',
                        style: AppTextStyles.price.copyWith(
                            fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.menuItemImage != null
                ? Image.network(
                    item.menuItemImage!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _imgFallback(),
                  )
                : _imgFallback(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menuItemName,
                  style: AppTextStyles.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('×${item.quantity}', style: AppTextStyles.bodySecondary),
              ],
            ),
          ),
          Text(
            'Rs. ${_fmt.format(item.total)}',
            style: AppTextStyles.itemPrice.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _imgFallback() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.restaurant, color: AppColors.textMuted, size: 22),
    );
  }

  Widget _buildViewMenuButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => context.go('/menu'),
        icon: const Icon(Icons.menu_book_outlined, color: AppColors.textPrimary),
        label: Text(
          'View Menu',
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status configuration
// Maps an order status string to the display data for the hero card.
// A plain class with const constructor keeps this pure data — no Flutter
// dependency — making it easy to unit test independently.
// ---------------------------------------------------------------------------

class _StatusConfig {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String timeLabel;

  const _StatusConfig({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
  });
}

_StatusConfig _statusConfig(String status) {
  // switch expression (Dart 3+) returns a value directly — more concise than
  // switch statement + intermediate variable.
  return switch (status) {
    'PENDING' => const _StatusConfig(
        icon: Icons.hourglass_top,
        color: AppColors.statusPendingText,
        title: 'Order Placed',
        subtitle: 'Waiting for kitchen confirmation',
        timeLabel: '~20 min',
      ),
    'CONFIRMED' => const _StatusConfig(
        icon: Icons.check_circle_outline,
        color: AppColors.statusConfirmedText,
        title: 'Order Confirmed',
        subtitle: 'Your order is in the queue',
        timeLabel: '~15 min',
      ),
    'PREPARING' => const _StatusConfig(
        icon: Icons.outdoor_grill,
        color: AppColors.primary,
        title: 'Being Prepared',
        subtitle: 'Our kitchen is working on your order',
        timeLabel: '~10 min',
      ),
    'READY' => const _StatusConfig(
        icon: Icons.restaurant,
        color: AppColors.statusReadyText,
        title: 'Ready!',
        subtitle: 'Your order is ready to be served',
        timeLabel: 'Ready now',
      ),
    'SERVED' => const _StatusConfig(
        icon: Icons.done_all,
        color: AppColors.statusServedText,
        title: 'Order Served',
        subtitle: 'Enjoy your meal!',
        timeLabel: 'Served',
      ),
    'COMPLETED' => const _StatusConfig(
        icon: Icons.check_circle,
        color: AppColors.statusCompletedText,
        title: 'Completed',
        subtitle: 'Thank you for dining with us!',
        timeLabel: 'Done',
      ),
    'CANCELLED' => const _StatusConfig(
        icon: Icons.cancel_outlined,
        color: AppColors.error,
        title: 'Cancelled',
        subtitle: 'Your order was cancelled',
        timeLabel: 'Cancelled',
      ),
    // Default handles any unexpected status strings from the backend
    _ => const _StatusConfig(
        icon: Icons.receipt_long,
        color: AppColors.textSecondary,
        title: 'Processing',
        subtitle: 'Updating your order status…',
        timeLabel: '...',
      ),
  };
}
