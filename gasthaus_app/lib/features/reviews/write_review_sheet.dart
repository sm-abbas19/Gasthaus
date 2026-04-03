import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// WriteReviewSheet is displayed as a modal bottom sheet — it slides up from
// the bottom of the screen over existing content rather than replacing it.
// It's shown via showModalBottomSheet() in OrdersScreen, not pushed as a route.
// Using showModalBottomSheet rather than a full screen keeps context:
// the user can see they're reviewing an item from a specific order.
class WriteReviewSheet extends StatefulWidget {
  final String menuItemId;
  final String menuItemName;
  final String? menuItemImage;
  final String orderId;

  const WriteReviewSheet({
    super.key,
    required this.menuItemId,
    required this.menuItemName,
    this.menuItemImage,
    required this.orderId,
  });

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  // Rating starts at 0 (no stars selected) — the submit button stays disabled
  // until the user selects at least 1 star.
  double _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  // Holds an inline error message shown below the submit button on failure.
  // Cleared when the user retries.
  String? _errorMessage;

  // _ratingLabel maps the current numeric rating to a human-readable label
  // shown below the stars (e.g. 4 stars → "Good").
  String get _ratingLabel {
    if (_rating == 0) return 'Tap to rate';
    if (_rating <= 1) return 'Poor';
    if (_rating <= 2) return 'Fair';
    if (_rating <= 3) return 'Average';
    if (_rating <= 4) return 'Good';
    return 'Excellent';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;

    // Clear any previous error before retrying.
    setState(() { _isSubmitting = true; _errorMessage = null; });
    try {
      // POST /reviews body per the backend spec:
      // { menuItemId, orderId, rating (int), comment? }
      await ApiService.instance.dio.post('/reviews', data: {
        'menuItemId': widget.menuItemId,
        'orderId': widget.orderId,
        'rating': _rating.round(), // flutter_rating_bar gives a double; backend expects int
        if (_commentController.text.trim().isNotEmpty)
          'comment': _commentController.text.trim(),
      });

      // Close the sheet — the orders list will refresh automatically.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Show the error inline below the submit button so the user
      // doesn't lose their typed review and can retry immediately.
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Padding.bottom of viewInsets.bottom pushes the sheet up when the
    // keyboard appears — otherwise the keyboard would cover the text field.
    // This is the standard pattern for keyboard-aware bottom sheets.
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        // 70% of screen height matches the stitch design.
        // Using a fixed height fraction rather than intrinsic size avoids
        // the sheet jumping in size as the user types.
        height: MediaQuery.of(context).size.height * 0.70,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildDragHandle(),
            Expanded(
              // SingleChildScrollView lets the content scroll if the keyboard
              // pushes it upward and content no longer fits.
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 28),
                    _buildStarRating(),
                    const SizedBox(height: 28),
                    _buildCommentInput(),
                    const SizedBox(height: 32),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    // The drag handle is a visual affordance indicating the sheet can be
    // swiped down to dismiss. Flutter's DraggableScrollableSheet handles
    // the gesture; we just render the indicator.
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Item thumbnail — if available
        if (widget.menuItemImage != null)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                widget.menuItemImage!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _imgFallback(),
              ),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Leave a Review',
                  style: AppTextStyles.screenTitle
                      .copyWith(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                widget.menuItemName,
                style: AppTextStyles.bodySecondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _imgFallback() {
    return Container(
      width: 56,
      height: 56,
      color: AppColors.divider,
      child: const Icon(Icons.restaurant,
          size: 24, color: AppColors.textMuted),
    );
  }

  Widget _buildStarRating() {
    return Column(
      children: [
        // RatingBar.builder from the flutter_rating_bar package.
        // It renders N star icons and calls onRatingUpdate with the selected value.
        // itemBuilder returns the widget for each star — we use filled/outlined
        // Material icons so no external assets are needed.
        // allowHalfRating: false means only whole-number ratings (1–5).
        Center(
          child: RatingBar.builder(
            initialRating: _rating,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: false,
            itemCount: 5,
            itemSize: 40,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4),
            itemBuilder: (context, _) => const Icon(
              Icons.star_rounded,
              color: AppColors.primary,
            ),
            unratedColor: AppColors.border,
            onRatingUpdate: (value) => setState(() => _rating = value),
          ),
        ),
        const SizedBox(height: 10),
        // Rating label fades in as the user selects stars
        AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            _ratingLabel,
            style: AppTextStyles.bodySecondary.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('YOUR REVIEW', style: AppTextStyles.sectionHeader),
        const SizedBox(height: 10),
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            TextField(
              controller: _commentController,
              maxLines: 5,
              maxLength: 500,
              // counterText '' hides the default Flutter character counter
              // so we can render our own in the corner via the Stack.
              maxLengthEnforcement:
                  MaxLengthEnforcement.enforced,
              style: AppTextStyles.body.copyWith(fontSize: 13),
              decoration: InputDecoration(
                counterText: '', // hide default counter
                hintText: 'Tell others what you think about this dish…',
                hintStyle:
                    AppTextStyles.body.copyWith(color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
              // Rebuild only the counter on each keystroke — using onChanged +
              // setState is simpler than a ValueNotifier for a single counter value.
              onChanged: (_) => setState(() {}),
            ),
            // Character counter overlay in the bottom-right of the textarea
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 10),
              child: Text(
                '${_commentController.text.length}/500',
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    // Button is disabled (_rating == 0) until the user selects at least 1 star.
    // ElevatedButton.onPressed = null renders the button in its disabled style.
    final canSubmit = _rating > 0 && !_isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: canSubmit ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.border,
              disabledForegroundColor: AppColors.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Text('Submit Review', style: AppTextStyles.buttonText),
          ),
        ),
        // Inline error — shown directly below the button so the user's
        // review text stays intact and they can fix the issue and retry.
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
