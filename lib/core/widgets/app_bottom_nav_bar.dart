import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int badgeCount;

  const AppNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badgeCount = 0,
  });
}

/// Reusable floating curved dock bottom navigation bar for Admin, Doctor & Patient modes.
class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavItem> items;
  final List<ScrollController>? scrollControllers;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.scrollControllers,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomPad = bottomInset > 0 ? bottomInset + 8.0 : 18.0;

    return Theme(
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.45)
                    : const Color(0xFF0F172A).withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = index == currentIndex;

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (index == currentIndex) {
                    final controller = (scrollControllers != null &&
                            index < scrollControllers!.length)
                        ? scrollControllers![index]
                        : PrimaryScrollController.maybeOf(context);
                    if (controller != null &&
                        controller.hasClients &&
                        controller.offset > 0) {
                      controller.animateTo(
                        0,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                      );
                    }
                    return;
                  }
                  onTap(index);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? AppColors.primary.withValues(alpha: 0.22)
                            : AppColors.primaryLight)
                        : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            size: 22,
                            color: isSelected
                                ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary)
                                : AppColors.textSecondaryOf(context),
                          ),
                          if (item.badgeCount > 0)
                            Positioned(
                              right: -8,
                              top: -5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: surfaceColor, width: 1.5),
                                ),
                                constraints: const BoxConstraints(minWidth: 16),
                                child: Text(
                                  item.badgeCount > 9 ? '9+' : '${item.badgeCount}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontSize: 11,
                          color: isSelected
                              ? (isDark ? const Color(0xFF38BDF8) : AppColors.primary)
                              : AppColors.textSecondaryOf(context),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
      ),
    );
  }
}

/// Reusable Visual Theme Preference Selector Card (System / Light / Dark) for Settings screens.
class ThemeModeSelectorCard extends ConsumerWidget {
  const ThemeModeSelectorCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);
    final isDark = AppColors.isDark(context);
    final activeAccent = isDark ? const Color(0xFF38BDF8) : AppColors.primary;

    final String activeModeLabel = switch (currentMode) {
      ThemeMode.system => 'System Default',
      ThemeMode.light => 'Light Mode',
      ThemeMode.dark => 'Dark Mode',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  size: 20,
                  color: activeAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance & Theme',
                      style: AppTypography.headline.copyWith(
                        fontSize: 15,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose how the interface looks across sessions',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  activeModeLabel,
                  style: AppTypography.caption.copyWith(
                    color: activeAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ThemePreviewTile(
                  mode: ThemeMode.system,
                  title: 'System',
                  subtitle: 'Auto device',
                  icon: Icons.brightness_auto_rounded,
                  isSelected: currentMode == ThemeMode.system,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.system),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ThemePreviewTile(
                  mode: ThemeMode.light,
                  title: 'Light',
                  subtitle: 'Clean daylight',
                  icon: Icons.light_mode_rounded,
                  isSelected: currentMode == ThemeMode.light,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ThemePreviewTile(
                  mode: ThemeMode.dark,
                  title: 'Dark',
                  subtitle: 'Low glare',
                  icon: Icons.dark_mode_rounded,
                  isSelected: currentMode == ThemeMode.dark,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(ThemeMode.dark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemePreviewTile extends StatelessWidget {
  final ThemeMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePreviewTile({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final activeColor = isDark ? const Color(0xFF38BDF8) : AppColors.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.14 : 0.06)
              : AppColors.surfaceVariantOf(context).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.borderOf(context),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniature UI Canvas Preview
            SizedBox(
              height: 58,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: _buildMiniScreenPreview(),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: AnimatedScale(
                      scale: isSelected ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected
                      ? activeColor
                      : AppColors.textSecondaryOf(context),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? AppColors.textPrimaryOf(context)
                          : AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontSize: 10.5,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniScreenPreview() {
    switch (mode) {
      case ThemeMode.light:
        return _MiniMockupPane(
          bgColor: const Color(0xFFF1F5F9),
          cardColor: Colors.white,
          lineColor: const Color(0xFFCBD5E1),
          accentColor: AppColors.primary,
          borderColor: const Color(0xFFE2E8F0),
        );
      case ThemeMode.dark:
        return _MiniMockupPane(
          bgColor: const Color(0xFF0B1120),
          cardColor: const Color(0xFF1E293B),
          lineColor: const Color(0xFF475569),
          accentColor: const Color(0xFF38BDF8),
          borderColor: const Color(0xFF334155),
        );
      case ThemeMode.system:
        return Row(
          children: [
            Expanded(
              child: _MiniMockupPane(
                bgColor: const Color(0xFFF1F5F9),
                cardColor: Colors.white,
                lineColor: const Color(0xFFCBD5E1),
                accentColor: AppColors.primary,
                borderColor: const Color(0xFFE2E8F0),
              ),
            ),
            Expanded(
              child: _MiniMockupPane(
                bgColor: const Color(0xFF0B1120),
                cardColor: const Color(0xFF1E293B),
                lineColor: const Color(0xFF475569),
                accentColor: const Color(0xFF38BDF8),
                borderColor: const Color(0xFF334155),
              ),
            ),
          ],
        );
    }
  }
}

class _MiniMockupPane extends StatelessWidget {
  final Color bgColor;
  final Color cardColor;
  final Color lineColor;
  final Color accentColor;
  final Color borderColor;

  const _MiniMockupPane({
    required this.bgColor,
    required this.cardColor,
    required this.lineColor,
    required this.accentColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini top bar
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Mini surface card 1
          Container(
            height: 14,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor, width: 0.7),
            ),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 3.5,
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Mini surface card 2
          Container(
            height: 11,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor, width: 0.7),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

