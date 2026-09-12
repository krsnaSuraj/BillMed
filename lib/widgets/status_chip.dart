import 'package:flutter/material.dart';

import '../models/bill_status.dart';
import '../theme/app_theme.dart';

/// Status pill for a [BillStatus]. Dark-mode safe, no hardcoded blacks/whites.
///
/// Set [onGradient] when the chip sits on a saturated gradient header
/// (bill detail hero): the normal translucent tint would wash out, so the
/// chip renders white-on-frost instead.
class StatusChip extends StatelessWidget {
  const StatusChip(
      {super.key,
      required this.status,
      this.compact = false,
      this.onGradient = false});

  final BillStatus status;
  final bool compact;
  final bool onGradient;

  Color get _color => switch (status) {
        BillStatus.unpaid => AppColors.danger,
        BillStatus.partial => AppColors.warning,
        BillStatus.paid => AppColors.success,
        BillStatus.overpaid => AppColors.info,
      };

  @override
  Widget build(BuildContext context) {
    final Color color = _color;
    if (onGradient) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
        ),
        child: Text(
          status.label,
          style: TextStyle(
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: compact ? 12 : 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
