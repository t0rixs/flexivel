import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';

/// Plan の予定一覧をタイムライン表示するウィジェット
/// 現在時刻に応じて滞中項目（青縁）・移動中（線上の円＋表示）を表示
class PlanTimeline extends StatefulWidget {
  const PlanTimeline({
    super.key,
    required this.plan,
    this.highlightItemId,
    this.debugNow,
  });

  final Plan plan;
  final String? highlightItemId;
  final DateTime? debugNow; // デバッグ用時刻オーバーライド

  @override
  State<PlanTimeline> createState() => _PlanTimelineState();
}

class _PlanTimelineState extends State<PlanTimeline> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = widget.debugNow ?? DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = widget.debugNow ?? DateTime.now());
    });
  }

  @override
  void didUpdateWidget(covariant PlanTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // debugNow が変更されたら即反映
    if (widget.debugNow != oldWidget.debugNow) {
      _now = widget.debugNow ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _isCurrentlyStaying(PlanItem item) {
    try {
      final start = DateTime.parse(item.startTime).millisecondsSinceEpoch;
      final end = start + item.stayMinutes * 60 * 1000;
      final nowMs = _now.millisecondsSinceEpoch;
      return start <= nowMs && nowMs < end;
    } catch (_) {
      return false;
    }
  }

  bool _isInTransitBetween(PlanItem from, PlanItem to) {
    try {
      final departMs = DateTime.parse(from.startTime).millisecondsSinceEpoch +
          from.stayMinutes * 60 * 1000;
      final arriveMs = DateTime.parse(to.startTime).millisecondsSinceEpoch;
      final nowMs = _now.millisecondsSinceEpoch;
      return departMs <= nowMs && nowMs < arriveMs;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.plan.items;
    if (items.isEmpty) {
      return const Center(child: Text('予定がありません'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      separatorBuilder: (context, index) {
        final isInTransit = index > 0 &&
            index < items.length &&
            _isInTransitBetween(items[index - 1]!, items[index]!);
        return _TimelineConnector(isInTransit: isInTransit);
      },
      itemBuilder: (context, index) {
        final item = items[index]!;
        final prevItem = index > 0 ? items[index - 1] : null;
        final isHighlighted = item.id == widget.highlightItemId;
        final isCurrentStay = _isCurrentlyStaying(item);
        return _PlanItemCard(
          item: item,
          prevItem: prevItem,
          isHighlighted: isHighlighted,
          isCurrentStay: isCurrentStay,
        );
      },
    );
  }
}

class _PlanItemCard extends StatelessWidget {
  const _PlanItemCard({
    required this.item,
    this.prevItem,
    this.isHighlighted = false,
    this.isCurrentStay = false,
  });
  final PlanItem item;
  final PlanItem? prevItem;
  final bool isHighlighted;
  final bool isCurrentStay;

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PlanItemDetailSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDate = _shouldShowDate(item.startTime);
    final timeStr = showDate
        ? _formatDateAndTime(item.startTime)
        : _formatTime(item.startTime);

    final borderColor = isHighlighted
        ? theme.colorScheme.error
        : isCurrentStay
            ? theme.colorScheme.primary
            : null;

    return InkWell(
      onTap: () => _showDetail(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isHighlighted
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: borderColor != null
              ? Border.all(color: borderColor, width: 2)
              : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 時刻（日付が変わるときは日付も表示）
            SizedBox(
              width: showDate ? 90 : 56,
              child: Text(
                timeStr,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: borderColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 場所名・住所・滞在時間（Places API の情報を表示）
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.address != null && item.address!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.address!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (item.stayMinutes > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '滞在 ${item.stayMinutes}分',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 閉店時刻
            if (item.closeTime != null)
              Text(
                '〜${_formatTime(item.closeTime!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowDate(String iso) {
    if (prevItem == null) return false;
    try {
      final dt = DateTime.parse(iso);
      final prevDt = DateTime.parse(prevItem!.startTime);
      return dt.year != prevDt.year ||
          dt.month != prevDt.month ||
          dt.day != prevDt.day;
    } catch (_) {
      return false;
    }
  }

  /// ISO から時刻を抽出。place のローカル時刻をそのまま表示（デバイス TZ に変換しない）
  String _formatTime(String iso) {
    try {
      final m = RegExp(r'T(\d{1,2}):(\d{2})').firstMatch(iso);
      if (m != null) return '${m[1]!.padLeft(2, '0')}:${m[2]}';
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _formatDateAndTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final time = _formatTime(iso);
      return '${dt.month}/${dt.day} $time';
    } catch (_) {
      return iso;
    }
  }
}

/// 予定の詳細を表示するボトムシート
class _PlanItemDetailSheet extends StatelessWidget {
  const _PlanItemDetailSheet({required this.item});
  final PlanItem item;

  String _formatTime(String iso) {
    try {
      final m = RegExp(r'T(\d{1,2}):(\d{2})').firstMatch(iso);
      if (m != null) return '${m[1]!.padLeft(2, '0')}:${m[2]}';
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final time = _formatTime(iso);
      return '${dt.month}月${dt.day}日 $time';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                item.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.schedule,
                label: '到着時刻',
                value: _formatDateTime(item.startTime),
              ),
              if (item.stayMinutes > 0)
                _DetailRow(
                  icon: Icons.timer_outlined,
                  label: '滞在時間',
                  value: '${item.stayMinutes}分',
                ),
              if (item.address != null && item.address!.isNotEmpty)
                _DetailRow(
                  icon: Icons.place_outlined,
                  label: '住所',
                  value: item.address!,
                ),
              if (item.closeTime != null)
                _DetailRow(
                  icon: Icons.store_outlined,
                  label: '閉店時刻',
                  value: _formatDateTime(item.closeTime!),
                ),
              if (item.deadline != null)
                _DetailRow(
                  icon: Icons.warning_amber_outlined,
                  label: '出発締切',
                  value: _formatDateTime(item.deadline!),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector({this.isInTransit = false});
  final bool isInTransit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = isInTransit
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    if (!isInTransit) {
      return Padding(
        padding: const EdgeInsets.only(left: 42, right: 335),
        child: SizedBox(
          width: 2,
          height: 24,
          child: ColoredBox(color: lineColor),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 42),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 2,
                  height: 12,
                  child: ColoredBox(color: lineColor),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                ),
                SizedBox(
                  width: 2,
                  height: 12,
                  child: ColoredBox(color: lineColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '移動中',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
