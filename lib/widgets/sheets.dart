import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Destructive/confirm bottom sheet. Returns true when confirmed.
bool _confirmSheetOpen = false;

Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool danger = true,
}) async {
  // Guard against double-tap opening two stacked sheets.
  if (_confirmSheetOpen) return false;
  _confirmSheetOpen = true;
  try {
    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (BuildContext sheetContext) {
        final Color accent = danger ? AppColors.danger : AppColors.success;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            // Scrollable: long names/counts must never clip the buttons on
            // short/landscape screens.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.warning_amber_rounded, color: accent),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textColor(sheetContext),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.subtitleColor(sheetContext),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          child: Text(confirmLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return result ?? false;
  } finally {
    _confirmSheetOpen = false;
  }
}

/// One option inside [showActionSheet].
class SheetAction<T> {
  const SheetAction({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final T value;
  final bool danger;
}

bool _actionSheetOpen = false;

/// Premium bottom action menu (replaces PopupMenuButton). Returns the
/// selected value, or null when dismissed.
Future<T?> showActionSheet<T>(
  BuildContext context, {
  String? title,
  required List<SheetAction<T>> options,
}) async {
  if (_actionSheetOpen) return null;
  _actionSheetOpen = true;
  try {
    return await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.subtitleColor(sheetContext),
                      ),
                    ),
                  ),
                ],
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final opt in options) _ActionTile<T>(option: opt),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  } finally {
    _actionSheetOpen = false;
  }
}

class _ActionTile<T> extends StatelessWidget {
  const _ActionTile({required this.option});

  final SheetAction<T> option;

  @override
  Widget build(BuildContext context) {
    final Color fg =
        option.danger ? AppColors.danger : AppColors.textColor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => Navigator.of(context).pop(option.value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (option.danger
                            ? AppColors.danger
                            : Theme.of(context).colorScheme.primary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(option.icon, size: 20, color: fg),
                ),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      if (option.subtitle != null)
                        Text(
                          option.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.subtitleColor(context),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating result snackbar: green on success, red on failure.
void showAppSnack(
  BuildContext context,
  String message, {
  bool success = true,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  // No hideCurrentSnackBar(): snackbars queue so action snackbars (e.g. the
  // delete Undo action) stay reachable instead of being dismissed by the
  // next message.
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontSize: 14, color: Colors.white),
      ),
      backgroundColor: success ? AppColors.success : AppColors.danger,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: success ? 4 : 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      action: (actionLabel != null && onAction != null)
          ? SnackBarAction(
              label: actionLabel,
              textColor: AppColors.accentLight,
              onPressed: onAction,
            )
          : null,
    ),
  );
}
