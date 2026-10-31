import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AutoCenterFilterItem {
  final String id;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const AutoCenterFilterItem({
    required this.id,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
}

/// Reusable horizontal filter pill bar that automatically scrolls the active/selected
/// chip to the center of the viewport (while naturally clamping items near the start or end).
class AutoCenterFilterBar extends StatefulWidget {
  final List<AutoCenterFilterItem> items;
  final String? focusItemId;
  final int scrollTrigger;
  final double height;
  final EdgeInsetsGeometry padding;

  const AutoCenterFilterBar({
    super.key,
    required this.items,
    this.focusItemId,
    this.scrollTrigger = 0,
    this.height = 36,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  State<AutoCenterFilterBar> createState() => _AutoCenterFilterBarState();
}

class _AutoCenterFilterBarState extends State<AutoCenterFilterBar> {
  final Map<String, GlobalKey> _itemKeys = {};

  GlobalKey _keyFor(String id) {
    return _itemKeys.putIfAbsent(id, () => GlobalKey());
  }

  String? _resolveTargetId() {
    if (widget.focusItemId != null) {
      return widget.focusItemId;
    }
    for (final item in widget.items) {
      if (item.isSelected) return item.id;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Only auto-scroll on mount if explicitly triggered by an external action
    if (widget.scrollTrigger > 0) {
      _scheduleCenter();
    }
  }

  @override
  void didUpdateWidget(covariant AutoCenterFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only auto-scroll when the selected filter changes OR an external navigation trigger fires
    if (widget.focusItemId != oldWidget.focusItemId ||
        widget.scrollTrigger != oldWidget.scrollTrigger) {
      _scheduleCenter();
    }
  }

  void _scheduleCenter({String? explicitId}) {
    final targetId = explicitId ?? _resolveTargetId();
    if (targetId == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _itemKeys[targetId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final activeColor = isDark ? const Color(0xFF38BDF8) : AppColors.primary;

    return SizedBox(
      height: widget.height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        child: Row(
          children: widget.items.map((item) {
            final itemKey = _keyFor(item.id);
            final isSelected = item.isSelected;

            return Padding(
              key: itemKey,
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  item.onTap();
                  _scheduleCenter(explicitId: item.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
                        : AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? activeColor
                          : AppColors.borderOf(context),
                    ),
                  ),
                  child: Text(
                    item.label,
                    style: AppTypography.caption.copyWith(
                      color: isSelected
                          ? activeColor
                          : AppColors.textSecondaryOf(context),
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

