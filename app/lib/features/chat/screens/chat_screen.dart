import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atmosphere_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/rich_markdown.dart';
import '../../home/providers/atmosphere_provider.dart';
import '../../home/theme/atmosphere_theme.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.initialPrompt});
  final String? initialPrompt;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    final prompt = widget.initialPrompt;
    if (prompt != null && prompt.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatProvider.notifier).send(prompt);
      });
    }
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(chatProvider.notifier).send(text);
    _scrollDown();
  }

  void _scrollDown() {
    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 80), () {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _copyMessage(String content) {
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('chat.copied'.tr()),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    ref.listen(chatProvider, (_, __) => _scrollDown());

    // Live sky: follows time of day AND the latest weather snapshot, and
    // repaints automatically as either changes.
    final palette = ref.watch(atmospherePaletteProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final navPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AtmosphereBackground(
            palette: palette,
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(sending: chat.sending, palette: palette),
                Expanded(
                  child: chat.messages.isEmpty && !chat.sending
                      ? _EmptyState(
                          palette: palette,
                          onSuggestion: (p) =>
                              ref.read(chatProvider.notifier).send(p),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                          itemCount:
                              chat.messages.length + (chat.sending ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (chat.sending && i == chat.messages.length) {
                              return const _TypingIndicator();
                            }
                            final m = chat.messages[i];
                            return _MessageBubble(
                              message: m,
                              onCopy: _copyMessage,
                            );
                          },
                        ),
                ),
                if (chat.error != null)
                  _ErrorBanner(
                    message: chat.error!,
                    onRetry: () => ref.read(chatProvider.notifier).retryLast(),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    navPad + bottomInset + 82,
                  ),
                  child: _Composer(
                    controller: _controller,
                    enabled: !chat.sending,
                    accent: palette.accent,
                    onSubmit: _send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Top bar: brand avatar, live status, conversation reset, voice handoff.
class _Header extends ConsumerWidget {
  const _Header({required this.sending, required this.palette});
  final bool sending;
  final AtmospherePalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.gradientAccent,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome,
                size: 19, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'chat.title'.tr(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16.5),
                ),
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            sending ? AppColors.statusAmber : AppColors.accent,
                        boxShadow: [
                          BoxShadow(
                            color: (sending
                                    ? AppColors.statusAmber
                                    : AppColors.accent)
                                .withValues(alpha: 0.7),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      sending ? 'chat.thinking'.tr() : 'chat.ready'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: sending
                            ? AppColors.statusAmber
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'chat.new_conversation'.tr(),
            onPressed: () => ref.read(chatProvider.notifier).clear(),
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: 'chat.voice'.tr(),
            onPressed: () => context.push('/voice/listening',
                extra: {'accent': AppColors.accent}),
            icon: const Icon(Icons.mic_none_rounded),
          ),
        ],
      ),
    );
  }
}

/// Welcome screen shown before the first message, with persona-aware
/// starter questions.
class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.palette, required this.onSuggestion});
  final AtmospherePalette palette;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(settingsProvider.select((s) => s.userPersona));
    final prompts = [
      'home.${persona}_prompt_1'.tr(),
      'home.${persona}_prompt_2'.tr(),
      'home.${persona}_prompt_3'.tr(),
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.gradientAccent,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.4),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 38, color: Colors.black),
            ),
            const SizedBox(height: 22),
            Text(
              'chat.welcome_title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'chat.welcome_subtitle'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 26),
            for (var i = 0; i < prompts.length; i++) ...[
              GlassCard(
                onTap: () => onSuggestion(prompts[i]),
                strong: i == 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                radius: 16,
                child: Row(
                  children: [
                    Icon(
                      Icons.near_me_outlined,
                      size: 16,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        prompts[i],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_upward_rounded,
                        size: 15, color: AppColors.textTertiary),
                  ],
                ),
              ),
              if (i != prompts.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// One conversation turn. Assistant turns render full markdown — tables,
/// code, LaTeX — via [RichMarkdown]; user turns stay plain text.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onCopy});
  final ChatMessage message;
  final ValueChanged<String> onCopy;

  static final DateFormat _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final user = message.role == 'user';
    final time = _timeFmt.format(message.at.toLocal());

    final Widget content = user
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.8,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2DD4BF), Color(0xFF38BDF8)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x382DD4BF),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              message.content,
              style: const TextStyle(
                height: 1.35,
                fontSize: 15,
                color: Color(0xFF07211F),
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        : GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.gradientAccent,
                      ),
                      child: const Icon(Icons.auto_awesome,
                          size: 12, color: Colors.black),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'WeatherGPT',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RichMarkdown(
                  message.content,
                  baseStyle: const TextStyle(fontSize: 15),
                ),
                if (message.meta?['intent_engine'] == 'system-one') ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded,
                          size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Builder(builder: (_) {
                        final confidence = message.meta?['intent_confidence'];
                        final pct = confidence is num
                            ? ' · ${(confidence.toDouble() * 100).round()}%'
                            : '';
                        return Text(
                          'Routed by System One$pct',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textTertiary,
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ],
            ),
          );

    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            user ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => onCopy(message.content),
            child: content,
          ),
          if (user)
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 6),
              child: Text(
                time,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// Three pulsing dots shown while the assistant is composing.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // `repeat()` needs a duration: without one the null-period check lives
    // inside an `assert`, so release builds crash in initState
    // (`period!` on null) and Flutter replaces this whole widget with the
    // gray release-mode error slab — the "gray box when chatting" bug.
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          radius: 20,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Opacity(
                    opacity: 0.35 + 0.65 * _wave(_c.value - i * 0.18),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Smooth 0→1→0 wave for one dot, phase-shifted per dot.
  double _wave(double t) {
    final x = (t % 1 + 1) % 1;
    final v = 1 - (2 * x - 1).abs();
    return v * v;
  }
}

/// Failure banner with a retry action, shown above the composer.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        decoration: BoxDecoration(
          color: AppColors.statusRed.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.statusRed.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 18, color: AppColors.statusRed),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.statusRed,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(
                'chat.retry'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded input with a gradient send button that lights up when there is
/// something to send.
class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.accent,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final Color accent;
  final VoidCallback onSubmit;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant _Composer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _onChanged();
    }
  }

  void _onChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText && mounted) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && _hasText;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: widget.controller,
            enabled: widget.enabled,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => widget.onSubmit(),
            style: const TextStyle(fontSize: 15, height: 1.3),
            decoration: InputDecoration(
              hintText: 'chat.hint'.tr(),
              filled: true,
              fillColor: AppColors.surfaceCard.withValues(alpha: 0.85),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: const BorderSide(color: AppColors.glassBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: widget.accent, width: 1.3),
              ),
            ),
          ),
        ),
        // The send button only occupies space when there is something to
        // send — an idle grey circle next to an empty field wasted a slot.
        ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: active ? 58 : 0,
            child: Opacity(
              opacity: active ? 1 : 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 10),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    elevation: 6,
                    shadowColor: AppColors.accent.withValues(alpha: 0.35),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: active ? widget.onSubmit : null,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.gradientAccent,
                        ),
                        child: const Icon(Icons.arrow_upward_rounded,
                            color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
