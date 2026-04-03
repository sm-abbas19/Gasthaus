import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/cart/cart_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final cartCount = context.watch<CartProvider>().itemCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: _BottomNav(
        currentLocation: location,
        cartCount: cartCount,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final String currentLocation;
  final int cartCount;

  const _BottomNav({
    required this.currentLocation,
    required this.cartCount,
  });

  int get _selectedIndex {
    if (currentLocation.startsWith('/menu')) return 0;
    if (currentLocation.startsWith('/orders')) return 1;
    if (currentLocation.startsWith('/ai-waiter')) return 2;
    if (currentLocation.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.bottom,
      decoration: const BoxDecoration(
        color: Colors.white,
        // Hairline top border separates the nav bar from screen content.
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.restaurant_menu_outlined,
              label: 'MENU',
              active: _selectedIndex == 0,
              onTap: () => context.go('/menu'),
            ),
            _NavItem(
              icon: Icons.receipt_long_outlined,
              label: 'ORDERS',
              active: _selectedIndex == 1,
              onTap: () => context.go('/orders'),
            ),
            _NavItem(
              icon: Icons.room_service_outlined,
              label: 'GUSTAV',
              active: _selectedIndex == 2,
              onTap: () => context.go('/ai-waiter'),
            ),
            _NavItem(
              icon: Icons.person_outline,
              label: 'PROFILE',
              active: _selectedIndex == 3,
              onTap: () => context.go('/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Active: brand amber. Inactive: dark grey — legible on the white bar.
    final color = active ? AppColors.primary : const Color(0xFF6B7280);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.navLabel.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
