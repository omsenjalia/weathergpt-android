import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/markdown_utils.dart';
import '../../../core/widgets/atmosphere_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/rich_markdown.dart';
import '../../home/providers/atmosphere_provider.dart';
import '../providers/voice_provider.dart';

/// Spoken-answer screen: what was heard, the full markdown answer, structured
/// stat chips when the backend sent a card, and the chat / ask-again actions.
class ConversationalResultScreen extends ConsumerStatefulWidget {
  const ConversationalResultScreen({super.key, required this.response});
  final VoiceResponse response;

  @override
  ConsumerState<ConversationalResultScreen> createState() =>
      _ConversationalResultScreenState();
}

class _ConversationalResultScreenState
    extends ConsumerState<ConversationalResultScreen> {
  var _spoke = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_spoke || !mounted) return;
      _spoke = true;
      final spoken =
          MarkdownUtils.spokenSummary('', widget.response.explanation);
      ref.read(voiceProvider.notifier).speak(spoken);
    });
  }

  String get _md {
    final body = RichMarkdown.sanitize(widget.response.explanation).trim();
    return body.isEmpty ? widget.response.verdict : body;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.response;
    final palette = ref.watch(atmospherePaletteProvider);
    // Opaque full-screen route — avoids shell bleed / multi-layer ghosting.
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        await ref.read(voiceProvider.notifier).stopSpeaking();
        ref.read(voiceProvider.notifier).cancel();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1220),
        body: Stack(
          fit: StackFit.expand,
          children: [
            AtmosphereBackground(
              palette: palette,
              secondaryGlowOverride: r.accent,
            ),
            Material(
              color: Colors.transparent,
              child: SafeArea(
                child: Column(
                  children: [
                    SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => _close(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                          Expanded(
                            child: Text(
                              'voice.result_title'.tr(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          if (r.transcript.trim().isNotEmpty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                margin:
                                    const EdgeInsets.only(bottom: 14, left: 44),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 15, vertical: 11),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      r.accent.withValues(alpha: 0.85),
                                      r.accent.withValues(alpha: 0.65),
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(6),
                                  ),
                                ),
                                child: Text(
                                  r.transcript,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          GlassCard(
                            padding:
                                const EdgeInsets.fromLTRB(18, 14, 18, 16),
                            radius: 22,
                            strong: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppColors.gradientAccent,
                                      ),
                                      child: const Icon(Icons.auto_awesome,
                                          size: 15, color: Colors.black),
                                    ),
                                    const SizedBox(width: 9),
                                    Text(
                                      r.label.isEmpty
                                          ? 'WeatherGPT'
                                          : r.label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                RichMarkdown(
                                  _md,
                                  baseStyle: const TextStyle(fontSize: 15.5),
                                ),
                                if (r.stats.isNotEmpty) ...[
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: r.stats
                                        .map(
                                          (s) => Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 13,
                                                vertical: 10),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.05),
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                              border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.08),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  s.label,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors
                                                        .textTertiary,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                                Text(
                                                  s.value,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    color: s.color ??
                                                        const Color(
                                                            0xFFF8FAFC),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await _stopVoice();
                                if (context.mounted) context.go('/chat');
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(
                                    color: AppColors.borderStrong),
                                minimumSize: const Size.fromHeight(50),
                                shape: const StadiumBorder(),
                              ),
                              child: const Text('Chat'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                await _stopVoice();
                                if (context.mounted) {
                                  context.pushReplacement('/voice/listening',
                                      extra: {'accent': AppColors.accent});
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.black,
                                minimumSize: const Size.fromHeight(50),
                                shape: const StadiumBorder(),
                              ),
                              child: Text('voice.ask_again'.tr()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stopVoice() async {
    await ref.read(voiceProvider.notifier).stopSpeaking();
    ref.read(voiceProvider.notifier).cancel();
  }

  Future<void> _close() async {
    await _stopVoice();
    if (mounted) context.go('/home');
  }
}
