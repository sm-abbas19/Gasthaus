import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gasthaus_wordmark.dart';
import 'auth_provider.dart';

// LoginScreen is a StatefulWidget because it owns mutable state:
// text field controllers, the password visibility toggle, and the loading flag.
//
// StatefulWidget vs StatelessWidget:
//   - StatelessWidget: no mutable state, just renders props
//   - StatefulWidget: has a companion State object that can call setState()
//     to trigger a rebuild when data changes
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // GlobalKey<FormState> connects this State to the Form widget below.
  // Calling _formKey.currentState!.validate() triggers all child
  // TextFormField validators at once and returns false if any fail.
  final _formKey = GlobalKey<FormState>();

  // TextEditingController is Flutter's way to read/write text field content
  // programmatically. Without it you can't get the current value on submit.
  // Must be disposed when the widget is removed from the tree to free memory.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Controls whether the password field shows dots or plain text.
  // Stored in State so toggling it calls setState() and rebuilds just this widget.
  bool _obscurePassword = true;

  // Holds the API-level error message (wrong password, account not found, etc.).
  // Null means no error is shown. We use setState() to update this so the
  // widget rebuilds and renders the error inline inside the card.
  String? _apiError;

  // Tracks whether a login request is in flight.
  // We derive this from AuthProvider.isLoading rather than keeping a local
  // copy — single source of truth principle.

  @override
  void dispose() {
    // Always dispose controllers when the State is destroyed.
    // Failing to do so leaks memory because the controller keeps a reference
    // to the text field even after the widget is gone.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Called when the user taps "Sign In".
  Future<void> _submit() async {
    // Clear any previous API error when the user retries.
    setState(() => _apiError = null);

    // validate() runs every TextFormField's validator in the Form.
    // If any returns a non-null string, that string appears inline below
    // the field as red error text, and validate() returns false — we stop here.
    if (!_formKey.currentState!.validate()) return;

    // context.read<T>() fetches a Provider without subscribing to rebuilds.
    // We use read (not watch) here because we only need to call a method,
    // not react to state changes inside this callback.
    final auth = context.read<AuthProvider>();

    try {
      await auth.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // `mounted` checks that this State is still attached to the widget tree.
      // After an async gap, the user might have navigated away — calling
      // context.go() on a detached context would throw.
      if (mounted) {
        // context.go() replaces the current route entirely.
        // Use go() (not push()) for top-level navigation so the back button
        // doesn't take the user back to the login screen after they've signed in.
        context.go('/menu');
      }
    } catch (_) {
      // Store the API error in state so it renders inline inside the card,
      // rather than floating as a SnackBar that the user might miss.
      if (mounted) {
        setState(() {
          _apiError = auth.error ?? 'Sign in failed. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.watch<T>() subscribes to the provider and rebuilds this widget
    // whenever AuthProvider calls notifyListeners(). This is how we get
    // live loading state updates without managing a local bool.
    final auth = context.watch<AuthProvider>();

    // Scaffold is the base page layout widget in Flutter — it provides
    // background color, safe area handling, and slots for AppBar, body, FAB, etc.
    return Scaffold(
      backgroundColor: AppColors.background,

      // SingleChildScrollView prevents overflow when the keyboard pushes the
      // layout up on smaller screens. Without it, RenderFlex overflow errors
      // appear when the soft keyboard is visible.
      body: SingleChildScrollView(
        // keyboardDismissBehavior closes the keyboard when the user scrolls —
        // a common UX pattern on form screens.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: SafeArea(
          // SafeArea adds padding to avoid the status bar, notch, and home indicator.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              // crossAxisAlignment.center centers children horizontally
              // in the Column (which runs vertically by default).
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 72),

                // Brand wordmark + tagline
                const GasthausWordmark(tagline: 'Your table is waiting.'),

                const SizedBox(height: 40),

                // Form card — white background, border, rounded corners
                _buildCard(auth),

                const SizedBox(height: 32),

                // Footer: link to register screen
                _buildFooter(),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(AuthProvider auth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      // Form groups TextFormFields so _formKey.currentState!.validate()
      // triggers all their validators in one call from _submit().
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header label — small caps, muted, tracked
            Text(
              'SIGN IN',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 11 * 0.3,
              ),
            ),

            const SizedBox(height: 28),

            // Email field
            // TextFormField = TextField + validator integration with the Form.
            // The validator runs on validate(); returning a non-null string
            // shows it as red text inline below the field.
            _buildFieldLabel('EMAIL'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              // keyboardType hints the OS to show an email keyboard (with @ key).
              keyboardType: TextInputType.emailAddress,
              // textInputAction controls the action button on the soft keyboard.
              // next moves focus to the next field instead of submitting.
              textInputAction: TextInputAction.next,
              autocorrect: false,
              // Disable autocorrect and suggestions for email — they interfere.
              enableSuggestions: false,
              decoration: const InputDecoration(
                hintText: 'you@example.com',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                return null; // null = valid, proceed
              },
            ),

            const SizedBox(height: 20),

            // Password field
            _buildFieldLabel('PASSWORD'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              // onFieldSubmitted is the TextFormField equivalent of onSubmitted.
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '••••••••',
                // suffixIcon is an icon/button inside the field on the right side.
                suffixIcon: GestureDetector(
                  onTap: () {
                    // setState() tells Flutter to rebuild this widget with
                    // the updated _obscurePassword value.
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 8),

            // Forgot password — right-aligned, amber text
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {}, // Not implemented — placeholder per spec
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot password?',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),

            // API error block — only shown when the server rejects credentials.
            // AnimatedSize smoothly expands/collapses the space so the button
            // doesn't jump abruptly when the error appears or clears.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _apiError != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          // Light red tint background to make the error prominent
                          // without relying on a floating SnackBar.
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _apiError!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              // SizedBox.shrink() collapses to zero size when there's no error,
              // so no extra blank space is reserved in the layout.
            ),

            const SizedBox(height: 20),

            // Sign In button — full width, amber, shows spinner when loading
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                // Disable the button while a request is in flight to prevent
                // double-submits. Setting onPressed to null disables it.
                onPressed: auth.isLoading ? null : _submit,
                child: auth.isLoading
                    // Show a spinner inside the button during loading.
                    // SizedBox constrains the CircularProgressIndicator so it
                    // doesn't fill the entire button height.
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        'SIGN IN',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 14 * 0.1,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // A small helper that renders the uppercase field label above an input.
  // Extracted to avoid repeating the same TextStyle on every label.
  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 11 * 0.08,
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        GestureDetector(
          // context.push() pushes /register onto the navigation stack,
          // so the back button returns here. Contrast with context.go()
          // which replaces the stack — wrong here because we want back to work.
          onTap: () => context.push('/register'),
          child: Text(
            'Create one',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
