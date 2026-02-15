import 'package:flutter/material.dart';

/// §5.1 / §6: warn 通知バナー
/// 「{minutes}分までに出発しないと、次の予定に間に合わない可能性があります。」
class WarnBanner extends StatelessWidget {
  const WarnBanner({super.key, required this.minutesToDeadline});

  final int minutesToDeadline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.orange.shade300, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$minutesToDeadline分までに出発しないと、次の予定に間に合わない可能性があります。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
