import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import '../theme/app_theme.dart';

class StatusBadge extends ConsumerWidget {
  final int billId;
  const StatusBadge({super.key, required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(billStatusProvider(billId));

    return statusAsync.when(
      data: (status) {
        final color = status == 'Paid'
            ? AppTheme.successColor
            : status == 'Partial'
                ? AppTheme.warningColor
                : AppTheme.dangerColor;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(status,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        );
      },
      error: (_, __) => const SizedBox(),
      loading: () => const SizedBox(),
    );
  }
}
