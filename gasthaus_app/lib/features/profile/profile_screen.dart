import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models/user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../auth/auth_provider.dart';
import '../orders/orders_provider.dart';

// ProfileScreen is a StatelessWidget because all its state comes from
// providers (AuthProvider, OrdersProvider). There's no local mutable state.
// If we needed to fetch additional profile data (e.g. review stats from an API),
// we'd upgrade this to StatefulWidget and add an initState fetch.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // context.watch() subscribes to both providers — the screen rebuilds
    // whenever the user logs in/out or the orders list changes.
    final auth = context.watch<AuthProvider>();
    final orders = context.watch<OrdersProvider>();
    final user = auth.currentUser;

    // Guard: if somehow the user is null (e.g. mid-logout), show nothing.
    // The router will redirect to /login shortly after logout is called.
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Dark identity strip: status bar + avatar + name + role
          _buildIdentityHeader(context, user),
          // Stats card overlaps the dark strip by extending into the white area
          _buildStatsCard(context, orders),
          const SizedBox(height: 28),
          _buildSection(
            context,
            label: 'ACCOUNT',
            items: [
              _SettingsRow(
                icon: Icons.person_outline,
                label: 'Full Name',
                value: user.name,
                onTap: () => _showEditNameDialog(context, user),
              ),
              _SettingsRow(
                icon: Icons.email_outlined,
                label: 'Email Address',
                value: user.email,
                onTap: () => _showInfoDialog(
                  context,
                  title: 'Email Address',
                  value: user.email,
                ),
              ),
              _SettingsRow(
                icon: Icons.lock_outline,
                label: 'Change Password',
                onTap: () => _showChangePasswordDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            label: 'SUPPORT',
            items: [
              _SettingsRow(
                icon: Icons.info_outline,
                label: 'About Gasthaus',
                onTap: () => _showAboutDialog(context),
              ),
              _SettingsRow(
                icon: Icons.description_outlined,
                label: 'Terms of Service',
                onTap: () => _showTermsDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Danger zone — log out button
          _buildLogoutSection(context, auth),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Identity header: dark background, avatar circle with initials, name, role
  // ---------------------------------------------------------------------------

  Widget _buildIdentityHeader(BuildContext context, User user) {
    return Container(
      // Extend the dark strip to include the status bar (SafeArea top)
      color: AppColors.darkSurface,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 36, // extra bottom so the stats card has room to overlap
      ),
      child: Row(
        children: [
          // Avatar: amber circle with white initials.
          // Using initials instead of an image because customers don't upload photos.
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15), width: 2),
            ),
            child: Center(
              child: Text(
                user.initials,
                style: AppTextStyles.screenTitle.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: AppTextStyles.topBarTitleLight.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 3),
              Text(
                // Capitalize the role label: "CUSTOMER" → "Customer"
                user.role[0] + user.role.substring(1).toLowerCase(),
                style: AppTextStyles.bodySecondary
                    .copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats card — overlaps the dark identity strip with negative top margin
  // ---------------------------------------------------------------------------

  Widget _buildStatsCard(BuildContext context, OrdersProvider orders) {
    // Derive stats from what we already have in memory — no extra API call.
    final totalOrders = orders.orders.length;
    final completedOrders =
        orders.orders.where((o) => o.isCompleted).length;

    return Padding(
      // Negative top margin pulls the card up over the dark header
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Transform.translate(
        // Shift up by 20px to overlap the dark strip
        offset: const Offset(0, -20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            // Subtle shadow to make the card "float" over the dark strip
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            // IntrinsicHeight makes all three stat columns the same height
            // so the vertical dividers stretch to fill the card.
            child: Row(
              children: [
                _StatCell(
                  value: '$totalOrders',
                  label: 'ORDERS',
                ),
                const VerticalDivider(
                    width: 1, color: AppColors.divider, thickness: 1),
                _StatCell(
                  value: '$completedOrders',
                  label: 'COMPLETED',
                  valueColor: AppColors.primary,
                ),
                const VerticalDivider(
                    width: 1, color: AppColors.divider, thickness: 1),
                _StatCell(
                  // Reviews stat would come from a dedicated endpoint in Phase 8.
                  // For now we show completed as a proxy.
                  value: orders.orders.isEmpty ? '--' : '★',
                  label: 'REVIEWS',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Settings section builder — card with labelled rows inside
  // ---------------------------------------------------------------------------

  Widget _buildSection(
    BuildContext context, {
    required String label,
    required List<_SettingsRow> items,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.sectionHeader),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            // ClipRRect so row highlights don't bleed outside the card corners
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Column(
                children: items.asMap().entries.map((entry) {
                  final isLast = entry.key == items.length - 1;
                  return Column(
                    children: [
                      entry.value,
                      if (!isLast)
                        const Divider(
                            height: 1,
                            indent: 52,
                            color: AppColors.divider),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Log Out section (danger zone — red text)
  // ---------------------------------------------------------------------------

  Widget _buildLogoutSection(BuildContext context, AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              // InkWell gives a ripple effect on tap — more appropriate than
              // GestureDetector here because it respects the Material theme ink.
              onTap: () => _confirmLogout(context, auth),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: AppColors.error, size: 22),
                    const SizedBox(width: 14),
                    Text(
                      'Log Out',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log Out'),
        content:
            const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              auth.logout();
              // GoRouter's redirect logic will detect isLoggedIn == false
              // and navigate to /login automatically.
              context.go('/login');
            },
            child: const Text(
              'Log Out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, User user) {
    final controller = TextEditingController(text: user.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Full Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter your name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: wire to PATCH /auth/me when the backend adds the endpoint
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Name update coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(
      BuildContext context, {required String title, required String value}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(value, style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              obscureText: true,
              decoration:
                  const InputDecoration(hintText: 'Current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration:
                  const InputDecoration(hintText: 'Confirm new password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: wire to backend password change endpoint
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password change coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('About Gasthaus'),
        content: const Text(
          'Gasthaus is an AI-powered restaurant management system '
          'that brings smart dining experiences to both customers and staff.\n\n'
          'Version 1.0.0',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'By using Gasthaus, you agree to our terms of service. '
            'Orders placed through the app are subject to the restaurant\'s '
            'availability and preparation times. Cancellations must be made '
            'before the order enters preparation. Reviews must be honest and '
            'reflect genuine experiences.\n\n'
            '© 2025 Gasthaus. All rights reserved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StatCell — one column in the stats card
// ---------------------------------------------------------------------------

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _StatCell({
    required this.value,
    required this.label,
    this.valueColor = AppColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: AppTextStyles.screenTitle
                  .copyWith(fontSize: 20, color: valueColor),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SettingsRow — a single tappable row in a settings section card
// ---------------------------------------------------------------------------

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value; // optional subtitle shown below label
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Material + InkWell gives a proper touch ripple scoped to the row.
    // We use Material(color: transparent) to keep the parent card's background
    // visible while still getting the ink effect.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppColors.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w500,
                    )),
                    // If a current value is provided, show it as a subtitle
                    if (value != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        value!,
                        style: AppTextStyles.bodySecondary.copyWith(
                            fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
