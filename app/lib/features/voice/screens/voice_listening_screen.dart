import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/atmosphere_background.dart';
import '../../home/providers/atmosphere_provider.dart';
import '../providers/voice_provider.dart';

class VoiceListeningScreen extends ConsumerStatefulWidget {
  const VoiceListeningScreen({super.key, this.accent, this.prompt});
  final Color? accent;
  final String? prompt;

  @override
  ConsumerState<VoiceListeningScreen> createState() =>
      _VoiceListeningScreenState();
}

class _VoiceListeningScreenState extends ConsumerState<VoiceListeningScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  var _started = false;
  var _navigated = false;

  Color get _accent => widget.accent ?? AppColors.accent;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_started || !mounted) return;
      _started = true;
      final p = widget.prompt?.trim();
      if (p != null && p.isNotEmpty) {
        ref.read(voiceProvider.notifier).submitQuery(p);
      } else {
        ref.read(voiceProvider.notifier).startListening();
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VoiceState>(voiceProvider, (_, next) {
      if (!_navigated &&
          next.status == VoiceStatus.done &&
          next.response != null &&
          mounted) {
        _navigated = true;
        context.pushReplacement('/voice/result', extra: next.response);
      }
    });

    final state = ref.watch(voiceProvider);
    final palette = ref.watch(atmospherePaletteProvider);
    final listening = state.status == VoiceStatus.listening;
    final processing = state.status == VoiceStatus.processing;
    final error = state.status == VoiceStatus.error;

    final statusText = error
        ? (state.errorMessage ?? 'voice.error'.tr())
        : processing
            ? 'voice.thinking'.tr()
            : listening
                ? 'voice.listening'.tr()
                : 'voice.speak_now'.tr();

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AtmosphereBackground(
            palette: palette,
            secondaryGlowOverride: _accent,
          ),
          Material(
            color: Colors.transparent,
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () async {
                        await ref.read(voiceProvider.notifier).stopSpeaking();
                        ref.read(voiceProvider.notifier).cancel();
                        if (context.mounted) {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/home');
                          }
                        }
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) {
                      final t = _pulse.value;
                      return SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            for (var i = 0; i < 3; i++)
                              Transform.scale(
                                scale: 0.55 + ((t + i * 0.3) % 1) * 0.7,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _accent.withValues(
                                        alpha: listening
                                            ? (1 - ((t + i * 0.3) % 1)) * 0.45
                                            : 0.08,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    _accent,
                                    Color.lerp(_accent, Colors.white, 0.18)!,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _accent.withValues(alpha: 0.5),
                                    blurRadius: 36,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                error
                                    ? Icons.error_outline_rounded
                                    : processing
                                        ? Icons.hourglass_top_rounded
                                        : Icons.mic_rounded,
                                size: 38,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    statusText,
                    style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      state.transcript.isEmpty
                          ? 'voice.hint'.tr()
                          : state.transcript,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: state.transcript.isEmpty
                            ? AppColors.textTertiary
                            : Colors.white,
                        height: 1.45,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (listening && !error)
                    TextButton(
                      onPressed: () => ref
                          .read(voiceProvider.notifier)
                          .stopListening(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                      ),
                      child: Text(
                        'voice.done_speaking'.tr(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  if (error)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: FilledButton(
                        onPressed: () {
                          _navigated = false;
                          ref.read(voiceProvider.notifier).startListening();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(50),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'voice.try_again'.tr(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
