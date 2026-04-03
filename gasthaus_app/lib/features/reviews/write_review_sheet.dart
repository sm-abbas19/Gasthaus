import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/models/order.dart';
import '../../core/models/review.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Opens the review sheet for the given [order].
///
/// If [existingReview] is non-null the sheet opens in READ-ONLY mode,
/// displaying the review the customer already left.
/// If null the sheet opens in WRITE mode so the customer can leave a review.
///
/// The call site (OrdersScreen) is responsible for fetching the existing review
/// before calling this function so it can pass the correct mode.
void showOrderReviewSheet(
  BuildContext context, {
  required Order order,
  Review? existingReview,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => OrderReviewSheet(
      order: order,
      existingReview: existingReview,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// OrderReviewSheet widget
// ─────────────────────────────────────────────────────────────────────────────

// StatefulWidget because write mode has local mutable state (rating, comment,
// loading flag). Read-only mode uses the same widget with all inputs disabled.
class OrderReviewSheet extends StatefulWidget {
  final Order order;
  final Review? existingReview; // non-null → read-only mode

  const OrderReviewSheet({
    super.key,
    required this.order,
    this.existingReview,
  });

  @override
  State<OrderReviewSheet> createState() => _OrderReviewSheetState();
}

class _OrderReviewSheetState extends State<OrderReviewSheet> {
  // In write mode these start at defaults; in read-only mode they're pre-filled
  // from existingReview and the UI elements are non-interactive.
  late double _rating;
  late final TextEditingController _commentController;
  bool _isSubmitting = false;
  String? _errorMessage;

  // True when the sheet is showing an existing review (read-only).
  bool get _readOnly => widget.existingReview != null;

  final _dateFmt = DateFormat('MMM d, y');

  String get _ratingLabel {
    if (_rating == 0) return 'Tap to rate';
    if (_rating <= 1) return 'Poor';
    if (_rating <= 2) return 'Fair';
    if (_rating <= 3) return 'Average';
    if (_rating <= 4) return 'Good';
    return 'Excellent';
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill from existing review if in read-only mode, otherwise start empty.
    _rating = widget.existingReview?.rating.toDouble() ?? 0;
    _commentController = TextEditingController(
      text: widget.existingReview?.comment ?? '',
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() { _isSubmitting = true; _errorMessage = null; });

    try {
      // POST /reviews — order-level, no menuItemId needed.
      // Body: { orderId, rating (int), comment? }
      await ApiService.instance.dio.post('/reviews', data: {
        'orderId': widget.order.id,
        'rating': _rating.round(),
        if (_commentController.text.trim().isNotEmpty)
          'comment': _commentController.text.trim(),
      });

      if (mounted) Navigator.of(context).pop(true); // pop with `true` = review submitted
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        // 72% height gives enough room for the order summary + stars + comment
        height: MediaQuery.of(context).size.height * 0.72,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildDragHandle(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildOrderSummary(),
                    const SizedBox(height: 24),
                    _buildStarRating(),
                    const SizedBox(height: 24),
                    _buildCommentInput(),
                    const SizedBox(height: 28),
                    if (!_readOnly) _buildSubmitButton(),
                    if (_readOnly) _buildReviewedBadge(),
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
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // Different titles for write vs read-only mode
          _readOnly ? 'Your Review' : 'Leave a Review',
          style: AppTextStyles.screenTitle.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 4),
        Text(
          // Show the short order ID reference below the title
          'Order #${widget.order.orderNumber}',
          style: AppTextStyles.bodySecondary,
        ),
        if (_readOnly && widget.existingReview != null) ...[
          const SizedBox(height: 2),
          Text(
            'Submitted ${_dateFmt.format(widget.existingReview!.createdAt.toLocal())}',
            style: AppTextStyles.caption,
          ),
        ],
      ],
    );
  }

  // Shows the list of items in the order so the customer remembers what they ate.
  // This replaces the old single-item thumbnail header.
  Widget _buildOrderSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORDER ITEMS',
            style: AppTextStyles.sectionHeader,
          ),
          const SizedBox(height: 10),
          // Render each order item as a single line: "× qty  Item Name"
          ...widget.order.items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                // Quantity badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '×${item.quantity}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.menuItemName,
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildStarRating() {
    return Column(
      children: [
        // In read-only mode the rating bar is non-interactive (ignoreGestures: true).
        // flutter_rating_bar respects this flag — stars render but taps do nothing.
        Center(
          child: RatingBar.builder(
            initialRating: _rating,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: false,
            itemCount: 5,
            itemSize: 40,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4),
            ignoreGestures: _readOnly, // disable interaction in read-only mode
            itemBuilder: (context, _) => const Icon(
              Icons.star_rounded,
              color: AppColors.primary,
            ),
            unratedColor: AppColors.border,
            onRatingUpdate: _readOnly ? (_) {} : (v) => setState(() => _rating = v),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            _ratingLabel,
            style: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.w500),
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
              maxLines: 4,
              maxLength: 500,
              // Read-only mode: disable keyboard and editing
              readOnly: _readOnly,
              enabled: !_readOnly,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              style: AppTextStyles.body.copyWith(fontSize: 13),
              decoration: InputDecoration(
                counterText: '',
                hintText: _readOnly
                    ? 'No written comment'
                    : 'Tell others about your experience…',
                hintStyle: AppTextStyles.body
                    .copyWith(color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: _readOnly ? AppColors.divider : AppColors.surface,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onChanged: _readOnly ? null : (_) => setState(() {}),
            ),
            if (!_readOnly)
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
                  borderRadius: BorderRadius.circular(10)),
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
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Shown in read-only mode instead of the submit button — a subtle badge
  // confirming the review was already submitted.
  Widget _buildReviewedBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            'Review submitted',
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
