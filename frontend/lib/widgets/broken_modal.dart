import 'package:flutter/material.dart';
import '../models/models.dart';

/// 仕様書_API仕様 §5.2: broken UI
/// options を表示: GO_NEXT ボタン / DETOUR候補3件リスト / SKIP ボタン
class BrokenModal extends StatelessWidget {
  const BrokenModal({
    super.key,
    required this.options,
    required this.onChoice,
    this.targetItemName,
  });

  final List<BrokenOption> options;
  final void Function(ApplyOptionChoice choice) onChoice;
  final String? targetItemName; // 破綻した予定の名前

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ハンドル
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // タイトル
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error, size: 28),
                const SizedBox(width: 8),
                Text(
                  '予定に間に合いません',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          if (targetItemName != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.place, size: 18, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        targetItemName!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '以下の選択肢から対応を選んでください。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Options
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (final option in options) _buildOption(context, option),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, BrokenOption option) {
    return switch (option) {
      BrokenOptionGoNext(:final reason) => _GoNextCard(
          reason: reason,
          onTap: () => onChoice(const ApplyOptionChoiceGoNext()),
        ),
      BrokenOptionDetour(:final reason, :final candidates) => _DetourSection(
          reason: reason,
          candidates: candidates,
          onSelect: (placeId) =>
              onChoice(ApplyOptionChoiceDetour(detourPlaceId: placeId)),
        ),
      BrokenOptionSkip(:final reason) => _SkipCard(
          reason: reason,
          onTap: () => onChoice(const ApplyOptionChoiceSkip()),
        ),
    };
  }
}

// ── GO_NEXT ──
class _GoNextCard extends StatelessWidget {
  const _GoNextCard({required this.reason, required this.onTap});
  final String reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.directions_run),
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('すぐ移動する'),
              Text(
                reason,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
    );
  }
}

// ── DETOUR ──
class _DetourSection extends StatelessWidget {
  const _DetourSection({
    required this.reason,
    required this.candidates,
    required this.onSelect,
  });
  final String reason;
  final List<DetourCandidate> candidates;
  final void Function(String placeId) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            '寄り道候補',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          reason,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final c in candidates) _DetourCandidateCard(
          candidate: c,
          onTap: () => onSelect(c.placeId),
        ),
      ],
    );
  }
}

class _DetourCandidateCard extends StatelessWidget {
  const _DetourCandidateCard({
    required this.candidate,
    required this.onTap,
  });
  final DetourCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = _formatTime(candidate.startTime);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 名前＋時間
              Row(
                children: [
                  Icon(Icons.place, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      candidate.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$time〜 ${candidate.stayMinutes}分',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 住所
              Text(
                candidate.address,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              // 理由
              Text(
                candidate.reason,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ── SKIP ──
class _SkipCard extends StatelessWidget {
  const _SkipCard({required this.reason, required this.onTap});
  final String reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.skip_next),
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('この予定をスキップ'),
              Text(
                reason,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
    );
  }
}
