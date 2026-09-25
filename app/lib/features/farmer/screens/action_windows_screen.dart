import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/rich_markdown.dart';
import '../providers/action_windows_provider.dart';
import '../widgets/time_window_bar.dart';

class ActionWindowsScreen extends ConsumerStatefulWidget {
  const ActionWindowsScreen({super.key});

  @override
  ConsumerState<ActionWindowsScreen> createState() =>
      _ActionWindowsScreenState();
}

class _ActionWindowsScreenState extends ConsumerState<ActionWindowsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(actionWindowsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(actionWindowsProvider);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Farm Action Windows',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text(
                  state.locationLabel.isEmpty
                      ? 'Anand, Gujarat'
                      : state.locationLabel,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
      ),
      body: SafeArea(
          // Pull to retry: after a failed load the screen stays explicitly
          // unavailable instead of guessing, so an explicit retry is needed.
          child: RefreshIndicator(
              color: AppColors.farmerGreen,
              onRefresh:
                  () => ref.read(actionWindowsProvider.notifier).refresh(),
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
            if (state.status == AdvisoryStatus.loading)
              const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(minHeight: 2)),
            if (state.status == AdvisoryStatus.unavailable)
              _NoticeBanner(
                  icon: Icons.cloud_off_rounded,
                  text: 'farmer.advisory_offline_banner'.tr()),
            _Tabs(
                selected: state.selectedTab,
                onSelect: ref.read(actionWindowsProvider.notifier).selectTab),
            const SizedBox(height: 20),
            if (state.hasWindows) ...[
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Row(children: [
                    Expanded(child: Text('6 AM', style: _scaleStyle)),
                    Expanded(
                        child: Text('12 PM',
                            textAlign: TextAlign.center, style: _scaleStyle)),
                    Expanded(
                        child: Text('6 PM',
                            textAlign: TextAlign.right, style: _scaleStyle)),
                  ])),
              const SizedBox(height: 12),
              _ActionRow(
                  label: 'farmer.irrigation'.tr(),
                  values: state.irrigationWindows,
                  captionColor: AppColors.farmerGreen),
              const SizedBox(height: 18),
              _ActionRow(
                  label: 'farmer.spraying'.tr(),
                  values: state.sprayingWindows,
                  captionColor: AppColors.statusAmber),
              const SizedBox(height: 18),
              _ActionRow(
                  label: 'farmer.field_work'.tr(),
                  caption: state.fieldWorkStatus,
                  values: state.fieldWorkWindows,
                  captionColor: AppColors.farmerGreen),
              if (state.asOfUtc != null)
                Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                        'farmer.last_verified'
                            .tr(namedArgs: {'time': _formatStamp(state.asOfUtc!)}),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textTertiary))),
              const SizedBox(height: 26),
            ] else ...[
              _UnavailableAdvisory(asOfUtc: state.asOfUtc),
              const SizedBox(height: 26),
            ],
            AppCard(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.farmerGreen, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            state.summaryVerdict.isNotEmpty
                                ? state.summaryVerdict
                                : 'farmer.advisory_unavailable'.tr(),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        // Advisory bodies come from the AI and may carry
                        // markdown (bullets, bold, tables) — render properly.
                        if (state.summaryExplanation.isNotEmpty)
                          RichMarkdown(
                            state.summaryExplanation,
                            baseStyle: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                            ),
                            textColor: AppColors.textSecondary,
                            accentColor: AppColors.farmerGreen,
                            selectable: false,
                          )
                        else
                          Text('farmer.advisory_unavailable_body'.tr(),
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.35)),
                        if (state.aiAssisted && state.aiConfidence != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: AppColors.farmerGreen
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Row(mainAxisSize: MainAxisSize.min,
                                      children: [
                                    const Icon(Icons.bolt_rounded,
                                        size: 13, color: AppColors.farmerGreen),
                                    const SizedBox(width: 4),
                                    Text(
                                        'System One · ${(state.aiConfidence! * 100).round()}% confident',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.farmerGreen)),
                                  ]))),
                      ])),
                ])),
          ]))),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderSubtle)),
        child: Row(children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary))),
        ]),
      );
}

const _scaleStyle = TextStyle(fontSize: 11, color: AppColors.textSecondary);

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelect});
  final ActionWindowTab selected;
  final ValueChanged<ActionWindowTab> onSelect;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(18)),
        child: Row(
            children: ActionWindowTab.values.map((tab) {
          final active = tab == selected;
          final label = switch (tab) {
            ActionWindowTab.today => 'Today',
            ActionWindowTab.tomorrow => 'Tomorrow',
            ActionWindowTab.sevenDay => '7 Days'
          };
          return Expanded(
              child: GestureDetector(
                  onTap: () => onSelect(tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: active ? AppColors.ctaWhite : Colors.transparent,
                        borderRadius: BorderRadius.circular(15)),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? AppColors.ctaTextDark
                                : AppColors.textSecondary)),
                  )));
        }).toList()),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow(
      {required this.label,
      this.caption,
      required this.values,
      required this.captionColor});
  final String label;

  /// Optional note from the backend. Absent means no note is rendered; the app
  /// never substitutes a canned "Best: 6–10 AM".
  final String? caption;
  final List<HourlySuitability> values;
  final Color captionColor;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        if (caption != null && caption!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(caption!,
              style: TextStyle(
                  fontSize: 12,
                  color: captionColor,
                  fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 9),
        TimeWindowBar(values: values),
      ]);
}

/// Formats a UTC stamp for the local reader without pretending to a precision
/// the backend did not provide.
String _formatStamp(DateTime utc) =>
    DateFormat('d MMM, HH:mm').format(utc.toLocal());

/// Shown instead of the window bars when nothing has been verified. Empty bars
/// would read as "everything is neutral", which is a claim the data does not
/// support.
class _UnavailableAdvisory extends StatelessWidget {
  const _UnavailableAdvisory({this.asOfUtc});
  final DateTime? asOfUtc;

  @override
  Widget build(BuildContext context) => AppCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.report_gmailerrorred_outlined,
            color: AppColors.statusAmber, size: 26),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('farmer.advisory_unavailable'.tr(),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text('farmer.advisory_unavailable_body'.tr(),
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.35)),
          if (asOfUtc != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'farmer.last_verified'
                        .tr(namedArgs: {'time': _formatStamp(asOfUtc!)}),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textTertiary))),
        ])),
      ]));
}
