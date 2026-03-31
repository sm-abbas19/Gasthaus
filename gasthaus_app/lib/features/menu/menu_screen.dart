import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_colors.dart';
import '../cart/cart_provider.dart';
import 'item_detail_sheet.dart';
import 'menu_provider.dart';
import 'widgets/menu_item_card.dart';

// MenuScreen is a StatefulWidget because it owns the search TextEditingController
// and reads the ?table= query param from the URL on first build.
// Everything else (data, filters) lives in MenuProvider.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Read the ?table= query param injected by a QR code scan.
    // A QR code on each restaurant table encodes the URL:
    //   gasthaus://menu?table=4
    // GoRouter parses this and makes it available via GoRouterState.
    //
    // We use addPostFrameCallback because reading GoRouterState and calling
    // a provider method during initState (before the first build) can cause
    // a setState-during-build error in some Flutter versions.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tableParam =
          GoRouterState.of(context).uri.queryParameters['table'];
      if (tableParam != null) {
        final tableNumber = int.tryParse(tableParam);
        if (tableNumber != null) {
          context.read<CartProvider>().setTableNumber(tableNumber);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Returns a greeting based on the current hour.
  // This is a simple computed value — no need to store it in state.
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    // context.watch() subscribes to CartProvider — this widget rebuilds
    // whenever the cart item count changes (so the badge stays current).
    final cartCount = context.watch<CartProvider>().itemCount;
    final tableNumber = context.watch<CartProvider>().tableNumber;

    // Column divides the screen into two vertical sections:
    // 1. Dark top bar (fixed height)
    // 2. Scrollable content (fills remaining space)
    return Column(
      children: [
        _buildTopBar(cartCount),
        Expanded(
          // CustomScrollView is the most efficient way to combine a fixed
          // header section with a scrollable grid. It uses "slivers" —
          // Flutter's term for scrollable sections of a scroll view.
          //
          // SliverToBoxAdapter wraps non-scrollable widgets so they can
          // live inside a CustomScrollView.
          // SliverGrid renders only the visible grid items, reusing cells
          // as you scroll (similar to RecyclerView in Android).
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildGreeting(tableNumber)),
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: _buildCategoryChips()),
              _buildMenuGrid(),
              // Bottom padding so the last row isn't hidden behind the nav bar.
              const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar(int cartCount) {
    return Container(
      color: AppColors.darkSurface, // #1C1C1E
      // SafeArea adds padding to avoid the status bar at the top.
      // bottom: false because the bottom safe area is handled by MainShell.
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Wordmark: amber icon + "GASTHAUS"
                const Icon(Icons.restaurant,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'GASTHAUS',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 17 * 0.2,
                  ),
                ),

                const Spacer(),

                // Cart icon with item count badge
                GestureDetector(
                  onTap: () => context.push('/cart'),
                  child: Stack(
                    // Stack sizes to the largest non-Positioned child.
                    // We use clipBehavior.none so the badge isn't clipped.
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.shopping_cart_outlined,
                        color: Color(0xFF9CA3AF), // zinc-400
                        size: 26,
                      ),
                      if (cartCount > 0)
                        // Positioned places the badge relative to the Stack.
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$cartCount',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Greeting + Table Chip ────────────────────────────────────────────────

  Widget _buildGreeting(int? tableNumber) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greeting,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'What would you like?',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          // Table indicator chip — only shown when a table number is set.
          // The table number comes from CartProvider (set via QR scan or
          // manually in Phase 8). For now it's null unless explicitly set.
          if (tableNumber != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.restaurant,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'TABLE $tableNumber',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB45309), // amber-700
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Search Bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: TextField(
        controller: _searchController,
        // Forward every keystroke to the provider's search query.
        // The provider's filteredItems getter reacts instantly.
        onChanged: (value) =>
            context.read<MenuProvider>().setSearchQuery(value),
        decoration: InputDecoration(
          hintText: 'Search dishes…',
          // prefixIcon is inside the text field on the left side.
          prefixIcon: const Icon(Icons.search,
              color: AppColors.textMuted, size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ─── Category Chips ───────────────────────────────────────────────────────

  Widget _buildCategoryChips() {
    // Consumer<T> is an alternative to context.watch<T>() that rebuilds only
    // the widget returned by its builder, rather than the whole parent.
    // Use it inside a heavy build() to limit rebuild scope.
    return Consumer<MenuProvider>(
      builder: (context, menu, _) {
        return SizedBox(
          height: 52,
          child: ListView(
            // Horizontal list of chips with invisible scrollbar.
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            children: [
              // "All" chip
              _CategoryChip(
                label: 'All',
                selected: menu.selectedCategoryId == null,
                onTap: () => menu.selectCategory(null),
              ),
              // One chip per category from the API
              ...menu.categories.map(
                (cat) => _CategoryChip(
                  label: cat.name,
                  selected: menu.selectedCategoryId == cat.id,
                  onTap: () => menu.selectCategory(cat.id),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Menu Grid ────────────────────────────────────────────────────────────

  Widget _buildMenuGrid() {
    return Consumer<MenuProvider>(
      builder: (context, menu, _) {
        // Show shimmer skeleton grid while the first fetch is in flight.
        // Shimmer gives users a visual hint of the content shape before
        // data arrives — much better UX than a spinner in the middle of a grid.
        if (menu.isLoading) {
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, _) => const _MenuItemShimmer(),
                childCount: 6, // show 6 ghost cards
              ),
            ),
          );
        }

        // Show error state with a retry button.
        if (menu.error != null) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
              child: Column(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(menu.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: menu.loadMenu,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final items = menu.filteredItems;

        if (items.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(
                child: Text('No items found.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          );
        }

        // SliverGrid renders grid cells lazily — only what's on screen.
        // SliverGridDelegateWithFixedCrossAxisCount gives a fixed 2-column layout.
        // childAspectRatio = width / height. 0.82 gives enough height for
        // the 4:3 image + name + price + bottom padding.
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = items[index];
                return MenuItemCard(
                  item: item,
                  // Tap the card → open detail sheet
                  onTap: () => showItemDetail(context, item),
                  // Tap "+" → quick-add 1 to cart + show snackbar
                  onAdd: () {
                    context.read<CartProvider>().addItem(item);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${item.name} added'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                  },
                );
              },
              childCount: items.length,
            ),
          ),
        );
      },
    );
  }
}

// ─── Menu Item Shimmer ────────────────────────────────────────────────────────
// Mimics the shape of a real MenuItemCard so the layout doesn't jump when
// data loads. Shimmer.fromColors animates a highlight sweep across grey boxes.

class _MenuItemShimmer extends StatelessWidget {
  const _MenuItemShimmer();

  @override
  Widget build(BuildContext context) {
    // Shimmer.fromColors wraps its child in a sweeping highlight animation.
    // baseColor is the "off" state, highlightColor is the shimmer peak.
    // The child defines the shape — use solid containers to show grey blocks.
    return Shimmer.fromColors(
      baseColor: AppColors.divider,
      highlightColor: AppColors.surface,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder — 4:3
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(color: AppColors.divider),
            ),
            // Text area placeholder
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: 60,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category Chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkSurface : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.darkSurface : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
