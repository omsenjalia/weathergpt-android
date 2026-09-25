import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../../features/explore/providers/map_provider.dart';
import '../../features/settings/providers/settings_provider.dart';

typedef _NavItem = ({
  String path,
  IconData icon,
  IconData activeIcon,
  String label,
});

const _homeItem = (
  path: '/home',
  icon: Icons.home_outlined,
  activeIcon: Icons.home_rounded,
  label: 'Home',
);
const _chatItem = (
  path: '/chat',
  icon: Icons.forum_outlined,
  activeIcon: Icons.forum_rounded,
  label: 'Chat',
);
const _mapItem = (
  path: '/explore',
  icon: Icons.public_outlined,
  activeIcon: Icons.public_rounded,
  label: 'Map',
);
const _farmItem = (
  path: '/farmer',
  icon: Icons.agriculture_outlined,
  activeIcon: Icons.agriculture_rounded,
  label: 'Farm',
);
const _labItem = (
  path: '/researcher',
  icon: Icons.analytics_outlined,
  activeIcon: Icons.analytics_rounded,
  label: 'Lab',
);
const _settingsItem = (
  path: '/profile',
  icon: Icons.tune_outlined,
  activeIcon: Icons.tune_rounded,
  label: 'Settings',
);

/// Floating pill navigation bar shared by all main app routes.
///
/// Frosted glass over the screen content, with a soft gradient pill that
/// slides between tabs and light haptics on selection. The tab set adapts to
/// the active persona: farmer and researcher modes get a dedicated tab for
/// their tools instead of burying them inside Settings.
class NavigationShell extends ConsumerWidget {
  const NavigationShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final persona = ref.watch(settingsProvider.select((s) => s.userPersona));

    final items = <_NavItem>[
      _homeItem,
      _chatItem,
      _mapItem,
      if (persona == 'farmer')
        _farmItem
      else if (persona == 'researcher')
        _labItem,
      _settingsItem,
    ];

    var currentIndex = 0;
    for (var i = 0; i < items.length; i++) {
      final path = items[i].path;
      if (location == path || location.startsWith('$path/')) {
        currentIndex = i;
        break;
      }
    }
    // Weather Lab has its own timeline/controls — hide app nav to avoid overlap.
    final hideNav = location.startsWith('/explore') &&
        ref.watch(mapProvider).source == MapSource.weatherLab;
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: child,
      extendBody: true,
      bottomNavigationBar: hideNav
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.bgElevated.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.glassBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 66,
                  child: Row(
                    children: List.generate(items.length, (i) {
                      final item = items[i];
                      final active = i == currentIndex;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (!active) HapticFeedback.selectionClick();
                            context.go(item.path);
                          },
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: Padding(
                              key: ValueKey(active),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: active ? 18 : 0,
                                      vertical: active ? 4 : 5,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: active
                                          ? AppColors.gradientAccent
                                          : null,
                                      borderRadius:
                                          BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      active
                                          ? item.activeIcon
                                          : item.icon,
                                      size: 21,
                                      color: active
                                          ? Colors.black
                                          : AppColors.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: active
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      letterSpacing: 0.2,
                                      color: active
                                          ? AppColors.accent
                                          : AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
    );
  }
}
