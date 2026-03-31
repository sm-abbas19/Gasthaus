import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/cart_item.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'cart_provider.dart';

// CartScreen is a StatefulWidget because it owns:
//  1. A TextEditingController for the special instructions field
//  2. A local _isPlacingOrder bool for the button loading state
// Everything cart-related (items, totals) comes from CartProvider via Consumer.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // TextEditingController must be disposed manually — it holds a native resource.
  // If we used a plain String and setState instead, we'd lose the text on every
  // CartProvider notification that rebuilds the tree. The controller survives rebuilds.
  final _notesController = TextEditingController();
  bool _isPlacingOrder = false;

  // NumberFormat from the `intl` package formats numbers with thousands separators.
  // '#,##0' = no decimal places, with comma grouping: 1250 → "1,250"
  final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  void dispose() {
    _notesController.dispose(); // release the text editing resource
    super.dispose();
  }

  Future<void> _placeOrder() async {
    // context.read<T>() reads a provider once without subscribing.
    // We use read() (not watch()) here because we're inside an async callback,
    // not a build method — watch() must only be called during build.
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) return;

    setState(() => _isPlacingOrder = true);

    try {
      // Build the POST /orders body.
      // Backend expects: { tableNumber, notes?, items: [{ menuItemId, quantity }] }
      final body = {
        'tableNumber': cart.tableNumber ?? 1,
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
        'items': cart.items
            .map((i) => {
                  'menuItemId': i.menuItem.id,
                  'quantity': i.quantity,
                })
            .toList(),
      };

      final response =
          await ApiService.instance.dio.post('/orders', data: body);

      // Extract the newly created order's ID to navigate to tracking screen.
      final orderId = response.data['id']?.toString() ?? '';

      // Clear the cart after successful order placement.
      cart.clear();

      // context.go() replaces the current route (cart) so the user can't
      // go "back" to a cleared cart. context.push() would keep cart in the stack.
      if (mounted) context.go('/orders/$orderId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // `mounted` check prevents setState after widget disposal —
      // important in async methods because the widget may have been
      // removed from the tree while the network request was in flight.
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consumer<CartProvider> rebuilds only this subtree when CartProvider calls
    // notifyListeners(). The third parameter `_` is the optional child that
    // does NOT rebuild — we don't use it here since the whole screen depends on cart.
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(context, cart),
          // Show empty state or scrollable content depending on cart state
          body: cart.items.isEmpty
              ? _buildEmptyState()
              : _buildBody(context, cart),
          // bottomNavigationBar is a Scaffold slot that stays fixed above
          // the system navigation bar — no manual padding needed.
          bottomNavigationBar:
              cart.items.isEmpty ? null : _buildBottomBar(context, cart),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, CartProvider cart) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.primary),
        // context.pop() goes back in the router stack — equivalent to Navigator.pop().
        // Use pop() for screens pushed on top (like this cart), go() for tab switches.
        onPressed: () => context.pop(),
      ),
      title: Text('Your Cart', style: AppTextStyles.topBarTitle),
      centerTitle: true,
      actions: [
        if (cart.items.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.textSecondary),
            onPressed: () => _showClearDialog(context, cart),
          ),
      ],
    );
  }

  void _showClearDialog(BuildContext context, CartProvider cart) {
    // showDialog is a Flutter function that overlays a Material AlertDialog.
    // The `_` in builder: (_) means we don't use the BuildContext provided —
    // we could also write `builder: (ctx) => AlertDialog(...)`.
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              cart.clear();
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined,
              size: 64, color: AppColors.border),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text('Add items from the menu',
              style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, CartProvider cart) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      children: [
        // Table indicator chip — only shown when a table number is set.
        // Table number is set via CartProvider.setTableNumber(), which is called
        // when a QR code is scanned (Phase 8) or from the menu screen query param.
        if (cart.tableNumber != null) _buildTableChip(cart.tableNumber!),
        if (cart.tableNumber != null) const SizedBox(height: 20),

        Text(
          'YOUR ORDER',
          style: AppTextStyles.sectionHeader,
        ),
        const SizedBox(height: 12),

        // Spread operator (...) inserts each card directly into the children list.
        // map() returns an Iterable<Widget> — we convert to a list of cards.
        ...cart.items.map(
          (item) => _CartItemCard(
            cartItem: item,
            onIncrement: () => context
                .read<CartProvider>()
                .updateQuantity(item.menuItem.id, item.quantity + 1),
            onDecrement: () => context
                .read<CartProvider>()
                .updateQuantity(item.menuItem.id, item.quantity - 1),
            onDismissed: () =>
                context.read<CartProvider>().removeItem(item.menuItem.id),
            fmt: _fmt,
          ),
        ),
        const SizedBox(height: 20),

        _buildNotesCard(),
        const SizedBox(height: 20),

        _buildSummaryCard(cart),
        // Extra bottom padding so the last card isn't hidden behind the sticky footer
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTableChip(int tableNumber) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.table_restaurant,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              'Table $tableNumber',
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SPECIAL INSTRUCTIONS', style: AppTextStyles.sectionHeader),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            maxLength: 300,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Any allergies or special requests?',
              hintStyle:
                  AppTextStyles.body.copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.divider,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none, // no visible border on the field itself
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              counterStyle: AppTextStyles.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(CartProvider cart) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _SummaryRow(
            label: 'Subtotal',
            value: 'Rs. ${_fmt.format(cart.subtotal)}',
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Tax (5%)',
            value: 'Rs. ${_fmt.format(cart.tax)}',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppColors.border.withValues(alpha: 0.7)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              Text(
                'Rs. ${_fmt.format(cart.total)}',
                style: AppTextStyles.price.copyWith(fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, CartProvider cart) {
    // SafeArea respects the device's system UI insets (home indicator on iPhone,
    // gesture navigation bar on Android). Without it, the button would be
    // partially hidden on notched/edge devices.
    return SafeArea(
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isPlacingOrder ? null : _placeOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              // disabledBackgroundColor shows while loading
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: _isPlacingOrder
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Place Order · Rs. ${_fmt.format(cart.total)}',
                        style: AppTextStyles.buttonText,
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CartItemCard
// A private widget (prefixed with _) is file-scoped — only usable within
// this file. This is a Flutter convention for sub-widgets that aren't
// shared across features.
// ---------------------------------------------------------------------------

class _CartItemCard extends StatelessWidget {
  final CartItem cartItem;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDismissed;
  final NumberFormat fmt;

  const _CartItemCard({
    required this.cartItem,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDismissed,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // Dismissible makes a widget swipeable to trigger an action (delete here).
      // key must be unique — ValueKey wraps a value as a stable widget identity.
      // Without a key, Flutter's reconciliation algorithm can't track which
      // item is which when the list changes.
      child: Dismissible(
        key: ValueKey(cartItem.menuItem.id),
        direction: DismissDirection.endToStart, // swipe left only
        onDismissed: (_) => onDismissed(),
        // The red background revealed behind the sliding card
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Top row: image + name + unit price
              Row(
                children: [
                  _buildImage(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cartItem.menuItem.name,
                          style: AppTextStyles.itemName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rs. ${fmt.format(cartItem.menuItem.price)}',
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Bottom row: quantity selector + running item total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _QuantitySelector(
                    quantity: cartItem.quantity,
                    onDecrement: onDecrement,
                    onIncrement: onIncrement,
                  ),
                  Text(
                    'Rs. ${fmt.format(cartItem.total)}',
                    style: AppTextStyles.itemPrice,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    // CachedNetworkImage would be ideal here for caching, but since cart items
    // are already loaded in MenuProvider we just use Image.network with
    // an error fallback. Phase 8 will upgrade to CachedNetworkImage + shimmer.
    final url = cartItem.menuItem.imageUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.restaurant, color: AppColors.textMuted, size: 28),
    );
  }
}

// ---------------------------------------------------------------------------
// _QuantitySelector  — pill-shaped [−] count [+] control
// ---------------------------------------------------------------------------

class _QuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QuantitySelector({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Pill container: high border-radius on a Row = rounded capsule shape
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(99),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _QtyButton(icon: Icons.remove, onTap: onDecrement),
          SizedBox(
            width: 32,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTextStyles.itemName,
            ),
          ),
          _QtyButton(icon: Icons.add, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // GestureDetector wraps any widget with touch detection.
    // We use it here instead of IconButton to avoid the default 48px
    // minimum tap target padding that IconButton adds — the pill container
    // already has enough padding.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SummaryRow  — label / value pair for order summary card
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
