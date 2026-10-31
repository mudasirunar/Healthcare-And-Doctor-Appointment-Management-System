import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Semantic tone for AppDialog headers and primary accents.
enum AppDialogTone {
  primary,
  success,
  warning,
  destructive,
  neutral,
}

/// A unified, highly customizable, clinical-grade dialog widget.
///
/// Follows the medical calm design language across both Light and Dark modes.
/// Supports optional top icons, title, description, custom widget content,
/// full button customization with loading spinners, and disabled states.
class AppDialog extends StatelessWidget {
  final IconData? icon;
  final AppDialogTone tone;
  final String title;
  final String? message;
  final Widget? content;
  final String? confirmLabel;
  final VoidCallback? onConfirm;
  final bool confirmIsDestructive;
  final bool confirmIsLoading;
  final bool confirmIsEnabled;
  final String? cancelLabel;
  final VoidCallback? onCancel;
  final bool cancelIsEnabled;
  final List<Widget>? customActions;
  final bool showCloseButton;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final CrossAxisAlignment alignment;

  const AppDialog({
    super.key,
    this.icon,
    this.tone = AppDialogTone.primary,
    required this.title,
    this.message,
    this.content,
    this.confirmLabel,
    this.onConfirm,
    this.confirmIsDestructive = false,
    this.confirmIsLoading = false,
    this.confirmIsEnabled = true,
    this.cancelLabel,
    this.onCancel,
    this.cancelIsEnabled = true,
    this.customActions,
    this.showCloseButton = false,
    this.maxWidth = 440,
    this.padding = const EdgeInsets.all(22),
    this.alignment = CrossAxisAlignment.center,
  });

  /// Static helper to display an AppDialog easily.
  static Future<T?> show<T>({
    required BuildContext context,
    bool barrierDismissible = true,
    required WidgetBuilder builder,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  /// Static helper for destructive deletion confirmation dialogs.
  static Future<bool?> showDestructive({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String cancelLabel = 'Cancel',
    IconData icon = Icons.delete_outline_rounded,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: icon,
        tone: AppDialogTone.destructive,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        confirmIsDestructive: true,
        onConfirm: () => Navigator.pop(ctx, true),
        cancelLabel: cancelLabel,
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
  }

  /// Static helper for standard confirmation dialogs.
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    String? message,
    Widget? content,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    IconData? icon,
    AppDialogTone tone = AppDialogTone.primary,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: icon,
        tone: tone,
        title: title,
        message: message,
        content: content,
        confirmLabel: confirmLabel,
        onConfirm: () => Navigator.pop(ctx, true),
        cancelLabel: cancelLabel,
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
  }

  /// Static helper for simple informational / alert dialogs.
  static Future<void> showInfo({
    required BuildContext context,
    required String title,
    required String message,
    String buttonLabel = 'Understood',
    IconData icon = Icons.info_outline_rounded,
    AppDialogTone tone = AppDialogTone.primary,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        icon: icon,
        tone: tone,
        title: title,
        message: message,
        confirmLabel: buttonLabel,
        onConfirm: () => Navigator.pop(ctx),
      ),
    );
  }

  Color _getToneColor(BuildContext context) {
    if (confirmIsDestructive) return AppColors.error;
    switch (tone) {
      case AppDialogTone.destructive:
        return AppColors.error;
      case AppDialogTone.warning:
        return AppColors.warning;
      case AppDialogTone.success:
        return AppColors.success;
      case AppDialogTone.primary:
        return AppColors.primary;
      case AppDialogTone.neutral:
        return AppColors.textSecondaryOf(context);
    }
  }

  Color _getToneLightColor(BuildContext context) {
    if (confirmIsDestructive) return AppColors.errorLightOf(context);
    switch (tone) {
      case AppDialogTone.destructive:
        return AppColors.errorLightOf(context);
      case AppDialogTone.warning:
        return AppColors.warningLightOf(context);
      case AppDialogTone.success:
        return AppColors.successLightOf(context);
      case AppDialogTone.primary:
        return AppColors.primaryLightOf(context);
      case AppDialogTone.neutral:
        return AppColors.surfaceVariantOf(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderColor = AppColors.borderOf(context);
    final surfaceColor = AppColors.surfaceOf(context);
    final toneColor = _getToneColor(context);
    final toneLightColor = _getToneLightColor(context);

    final hasPrimary = confirmLabel != null;
    final hasSecondary = cancelLabel != null;

    return Dialog(
      backgroundColor: surfaceColor,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor.withValues(alpha: 0.7)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: alignment,
                children: [
                  // 1. Icon (Top Center)
                  if (icon != null) ...[
                    Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: toneLightColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: toneColor, size: 24),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. Title & Message (Properly Centered across full width)
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      title,
                      textAlign: alignment == CrossAxisAlignment.center
                          ? TextAlign.center
                          : TextAlign.start,
                      style: AppTypography.headline.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  if (message != null && message!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        message!,
                        textAlign: alignment == CrossAxisAlignment.center
                            ? TextAlign.center
                            : TextAlign.start,
                        style: AppTypography.bodyMedium.copyWith(
                          color: textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],

                  // 3. Custom Content (Form fields, lists, extra info)
                  if (content != null) ...[
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: content!,
                      ),
                    ),
                  ],

                  // 4. Action Buttons Section
                  if (customActions != null) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: customActions!,
                    ),
                  ] else if (hasPrimary || hasSecondary) ...[
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        if (hasSecondary)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: (cancelIsEnabled && !confirmIsLoading)
                                  ? onCancel
                                  : null,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: borderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                minimumSize: const Size.fromHeight(44),
                                foregroundColor: textPrimary,
                              ),
                              child: Text(
                                cancelLabel!,
                                style: AppTypography.button.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                          ),
                        if (hasPrimary && hasSecondary)
                          const SizedBox(width: 12),
                        if (hasPrimary)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (confirmIsEnabled && !confirmIsLoading)
                                  ? onConfirm
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: toneColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    toneColor.withValues(alpha: 0.5),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                minimumSize: const Size.fromHeight(44),
                              ),
                              child: confirmIsLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      confirmLabel!,
                                      style: AppTypography.button.copyWith(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
              if (showCloseButton)
                Positioned(
                  top: 0,
                  right: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

