import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../menu/menu_provider.dart';
import 'ai_chat_provider.dart';

// Suggestion chips shown in the welcome banner.
// Top-level const so it's not re-created on every build.
const _suggestions = [
  "What's popular today?",
  "I'm vegetarian",
  "Something spicy",
  "Best dessert?",
];

// AiWaiterScreen is a StatefulWidget because it needs:
//   1. A TextEditingController for the input field
//   2. A ScrollController to auto-scroll to the latest message
//   3. initState to wire up the scroll listener
class AiWaiterScreen extends StatefulWidget {
  const AiWaiterScreen({super.key});

  @override
  State<AiWaiterScreen> createState() => _AiWaiterScreenState();
}

class _AiWaiterScreenState extends State<AiWaiterScreen> {
  final _textController = TextEditingController();
  // ScrollController lets us programmatically scroll the message list.
  // We use it to jump to the bottom whenever a new message is added.
  final _scrollController = ScrollController();
  // Local state tracking whether the text field has content —
  // used to enable/disable the send button.
  bool _hasText = false;
  final _timeFmt = DateFormat('h:mm a');

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      // Only call setState if the value actually changed — avoids unnecessary rebuilds.
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // _scrollToBottom jumps the list to the very last item.
  // Called after sendMessage() so the latest message is always visible.
  // addPostFrameCallback ensures the scroll runs after Flutter has finished
  // laying out the new message widget — if we scrolled immediately, the
  // new item might not be in the layout tree yet and the scroll would be too short.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Clear the text field immediately so the user can type again right away.
    // We clear before the await so the field is empty even while the AI is responding.
    _textController.clear();
    _scrollToBottom();

    // Build the full menu items list — including unavailable items — so the AI
    // knows the complete catalogue and can accurately report each item's status.
    // Omitting unavailable items causes the AI to hallucinate their availability
    // from session history. Sending all items with an explicit `available` flag
    // lets the AI say "X is currently unavailable" correctly.
    final menuItems = context
        .read<MenuProvider>()
        .allItems
        .map((item) => {
              'id': item.id,
              'name': item.name,
              'description': item.description,
              'price': item.price,
              'categoryName': item.categoryName,
              'isAvailable': item.available,
            })
        .toList();

    // context.read() is used here (not watch()) because we're in an async callback,
    // not in the build() method. context.watch() must only be called during build.
    await context.read<AiChatProvider>().sendMessage(text, menuItems: menuItems);
    _scrollToBottom(); // scroll again after AI response arrives
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiChatProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          // resizeToAvoidBottomInset: true (default) pushes the whole scaffold up
          // when the keyboard appears. Combined with the input bar being in the
          // bottomNavigationBar slot, this keeps the input visible above the keyboard.
          body: Column(
            children: [
              _buildHeader(provider),
              Expanded(
                child: provider.isEmpty
                    ? _buildWelcomeBanner(provider)
                    : _buildMessageList(provider),
              ),
            ],
          ),
          bottomNavigationBar: _buildInputBar(),
        );
      },
    );
  }

  // Custom top bar matching the app's dark amber header colour.
  Widget _buildHeader(AiChatProvider provider) {
    return Container(
      // SafeArea.top respects the status bar height on notched devices.
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
      ),
      color: AppColors.primaryDark,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // Sparkle icon — filled variant via fontVariations
              const Icon(Icons.room_service, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text('Gustav', style: AppTextStyles.topBarTitleLight),
              const Spacer(),
              // Clear button is always active — the server-side MongoDB session
              // can persist across app restarts even when local messages are gone,
              // so the user must be able to clear it at any time.
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: () => provider.clearSession(),
                tooltip: 'New conversation',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Welcome banner shown when no messages exist.
  // Contains a prompt card + suggestion chips that pre-fill the input.
  Widget _buildWelcomeBanner(AiChatProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: Column(
        children: [
          // Amber-tinted card with sparkle icon and welcome text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Column(
              children: [
                const Icon(Icons.room_service,
                    size: 48, color: AppColors.primary),
                const SizedBox(height: 14),
                Text(
                  'Guten Tag! I\'m Gustav.',
                  style: AppTextStyles.screenTitle.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your personal Gasthaus waiter. Tell me what you\'re in the mood for and I\'ll find the perfect dish for you.',
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Suggestion chips — tapping one fills the input and sends immediately
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _suggestions
                .map((s) => _SuggestionChip(
                      label: s,
                      onTap: () {
                        _textController.text = s;
                        _sendMessage();
                      },
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // The scrollable message list with a typing indicator at the bottom.
  Widget _buildMessageList(AiChatProvider provider) {
    // Total items = messages + (1 if typing indicator is showing)
    final itemCount =
        provider.messages.length + (provider.isTyping ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        // The last item is the typing indicator when isTyping is true
        if (provider.isTyping && i == provider.messages.length) {
          return const _TypingIndicator();
        }
        final msg = provider.messages[i];
        return msg.isUser
            ? _UserBubble(message: msg, timeFmt: _timeFmt)
            : _AiBubble(message: msg, timeFmt: _timeFmt);
      },
    );
  }

  // Input bar: text field + circular send button.
  // Placed in Scaffold.bottomNavigationBar so it sits directly above the
  // MainShell's bottom nav and rises with the keyboard automatically.
  Widget _buildInputBar() {
    return SafeArea(
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Row(
          children: [
            // Flexible text field — takes all remaining width
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _textController,
                  style: AppTextStyles.body.copyWith(fontSize: 14),
                  // textInputAction.send shows a "Send" key on the keyboard
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Ask about the menu…',
                    hintStyle: AppTextStyles.body.copyWith(
                        color: AppColors.textMuted, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Circular amber send button — disabled when field is empty
            GestureDetector(
              onTap: _hasText ? _sendMessage : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _hasText ? AppColors.primary : AppColors.border,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  size: 20,
                  color: _hasText ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _UserBubble — right-aligned amber message bubble
// ---------------------------------------------------------------------------

class _UserBubble extends StatelessWidget {
  final ChatMessage message;
  final DateFormat timeFmt;

  const _UserBubble({required this.message, required this.timeFmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Constrain to 75% of screen width to match the stitch design
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                // Asymmetric border radius: all corners 16px except bottom-right 4px
                // This creates the "chat tail" effect pointing to the sender.
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                message.text,
                style: AppTextStyles.body.copyWith(
                    color: Colors.white, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeFmt.format(message.timestamp),
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AiBubble — left-aligned white message bubble with "AI Waiter" label
// ---------------------------------------------------------------------------

class _AiBubble extends StatelessWidget {
  final ChatMessage message;
  final DateFormat timeFmt;

  const _AiBubble({required this.message, required this.timeFmt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gustav label above each AI bubble
          Row(
            children: [
              const Icon(Icons.room_service,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                'GUSTAV',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4), // "tail" on the left
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: AppColors.border),
              ),
              // MarkdownBody renders ** bold **, * italic *, line breaks etc.
              // The AI (Gemini) returns markdown-formatted text, so we must
              // parse it here — otherwise **bold** shows as raw asterisks.
              // shrinkWrap: true makes MarkdownBody size to its content
              // instead of trying to fill the parent, which is important
              // inside a ConstrainedBox inside a scrollable list.
              child: MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet(
                  p: AppTextStyles.body.copyWith(fontSize: 14, height: 1.6),
                  strong: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                  // Remove default top/bottom padding from paragraphs
                  // so spacing matches the original Text widget layout.
                  blockSpacing: 10,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeFmt.format(message.timestamp),
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TypingIndicator — three animated dots shown while the AI is responding
// ---------------------------------------------------------------------------

// Uses StatefulWidget + AnimationController to drive the dots.
// Each dot fades in and out with a staggered delay to create a wave effect.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  // TickerProviderStateMixin (not "Single") is used here because we need
  // three separate AnimationControllers — one per dot.
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    // Create one controller per dot with a staggered start delay.
    // The delay creates the cascading wave: dot 1 starts, then 2, then 3.
    _controllers = List.generate(3, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      // Future.delayed staggers each dot's start by 200ms
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) controller.repeat(reverse: true);
      });
      return controller;
    });

    _animations = _controllers
        .map((c) => Tween<double>(begin: 0.3, end: 1.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  // FadeTransition drives opacity from _animations[i].
                  // It's more efficient than AnimatedOpacity + setState because
                  // it bypasses the build/layout phases — only the composite step runs.
                  child: FadeTransition(
                    opacity: _animations[i],
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SuggestionChip — tappable chip in the welcome banner
// ---------------------------------------------------------------------------

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
              fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
