import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Reusable smart search bar widget for Doctors, Patients, Appointments, and Specialties.
/// Features rounded corners and an automatic clear ('X') button when at least 1 character is typed.
class AppSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;

  const AppSearchBar({
    super.key,
    this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.trailing,
    this.margin,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleClear() {
    _controller.clear();
    widget.onChanged('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    final surfaceColor = AppColors.surfaceOf(context);
    final borderColor = AppColors.borderOf(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Container(
      margin: widget.margin,
      height: 46,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.search_rounded,
            size: 20,
            color: hasText ? AppColors.primary : textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              style: AppTypography.bodyMedium.copyWith(
                color: textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: textSecondary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
          if (hasText)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleClear,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: textPrimary,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 12),
          if (widget.trailing != null) ...[
            widget.trailing!,
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

