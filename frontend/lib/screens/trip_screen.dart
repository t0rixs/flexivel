import 'package:flutter/material.dart';
import '../state/trip_state.dart';
import '../widgets/plan_timeline.dart';
import '../widgets/warn_banner.dart';
import '../widgets/broken_modal.dart';
import 'plan_input_screen.dart';

/// 仕様書_API仕様 §5: メイン画面（Plan表示 + warn/broken 対応）
class TripScreen extends StatefulWidget {
  const TripScreen({super.key, required this.tripState});
  final TripState tripState;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  TripState get _state => widget.tripState;
  bool _brokenModalShowing = false;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    // 起動時: Firestore から plan を読み込む
    _state.initialize().then((_) {
      // plan があれば定期チェック開始
      if (_state.hasPlan) {
        _state.startPeriodicCheck();
      }
    });
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {});

    // §5.1: broken → モーダル表示（二重表示防止）
    if (_state.status == TripStatus.broken &&
        _state.brokenOptions != null &&
        !_brokenModalShowing) {
      _showBrokenModal();
    }
  }

  void _showBrokenModal() {
    _brokenModalShowing = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => BrokenModal(
        options: _state.brokenOptions!,
        onChoice: (choice) {
          Navigator.of(context).pop();
          _state.applyChoice(choice);
        },
      ),
    ).whenComplete(() {
      _brokenModalShowing = false;
    });
  }

  Future<void> _openPlanInput() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlanInputScreen(tripState: _state),
      ),
    );
    if (created == true && _state.hasPlan) {
      _state.startPeriodicCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flexivel'),
        centerTitle: true,
        actions: [
          // 手動チェックボタン（plan がある場合のみ）
          if (_state.hasPlan)
            IconButton(
              onPressed: _state.status == TripStatus.loading
                  ? null
                  : () => _state.performCheck(),
              icon: const Icon(Icons.refresh),
              tooltip: 'チェック実行',
            ),
        ],
      ),
      body: Column(
        children: [
          // ── warn バナー ──
          if (_state.status == TripStatus.warn &&
              _state.minutesToDeadline != null)
            WarnBanner(minutesToDeadline: _state.minutesToDeadline!),

          // ── エラー表示 ──
          if (_state.errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: theme.colorScheme.errorContainer,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _state.errorMessage!,
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _state.clearError(),
                  ),
                ],
              ),
            ),

          // ── loading ──
          if (_state.status == TripStatus.loading)
            const LinearProgressIndicator(),

          // ── Plan タイムライン or 空状態 ──
          Expanded(
            child: _state.hasPlan
                ? PlanTimeline(
                    plan: _state.plan!,
                    highlightItemId: _state.warnTargetItemId ??
                        _state.brokenTargetItemId,
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 64,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '旅程がまだありません',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _openPlanInput,
                          icon: const Icon(Icons.add),
                          label: const Text('旅程を作成'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      // plan がある場合も新規作成/編集ボタン
      floatingActionButton: _state.hasPlan
          ? FloatingActionButton(
              onPressed: _openPlanInput,
              tooltip: '新しい旅程を作成',
              child: const Icon(Icons.edit_calendar),
            )
          : null,
    );
  }
}
