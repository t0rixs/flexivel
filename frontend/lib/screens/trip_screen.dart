import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../state/trip_state.dart';
import '../widgets/plan_timeline.dart';
import '../widgets/warn_banner.dart';
import '../widgets/broken_modal.dart';
import 'plan_input_screen.dart';

/// デバッグパネルを表示するか
/// flutter run（debug）では kDebugMode=true で自動表示
/// リリースビルドでは --dart-define=SHOW_DEBUG=true で有効化
const _showDebugPanel =
    kDebugMode || bool.fromEnvironment('SHOW_DEBUG', defaultValue: false);

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
    // 破綻対象の予定名を取得
    String? targetName;
    if (_state.brokenTargetItemId != null && _state.plan != null) {
      try {
        targetName = _state.plan!.items
            .firstWhere((item) => item.id == _state.brokenTargetItemId)
            .name;
      } catch (_) {}
    }

    _brokenModalShowing = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => BrokenModal(
        options: _state.brokenOptions!,
        targetItemName: targetName,
        onChoice: (choice) {
          Navigator.of(context).pop();
          _state.applyChoice(choice);
        },
      ),
    ).whenComplete(() {
      _brokenModalShowing = false;
    });
  }

  // ── デバッグ: 時刻ピッカー ──
  Future<void> _pickDebugTime() async {
    final now = _state.debugNow ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (time == null || !mounted) return;

    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    _state.setDebugTime(selected);
  }

  // ── デバッグ: 位置ピッカー（plan item の場所を選択） ──
  void _pickDebugLocation() {
    final items = _state.plan?.items ?? [];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('現在地を選択', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ...items.map((item) => ListTile(
                leading: const Icon(Icons.place),
                title: Text(item.name),
                subtitle: Text('${item.lat.toStringAsFixed(4)}, ${item.lng.toStringAsFixed(4)}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _state.setDebugLocation(item.lat, item.lng);
                },
              )),
              ListTile(
                leading: const Icon(Icons.my_location),
                title: const Text('実際の現在地を使用'),
                onTap: () {
                  Navigator.pop(ctx);
                  _state.setDebugLocation(_state.debugLat ?? 0, _state.debugLng ?? 0);
                  // 位置をクリア（実際の GPS を使う）
                  _state.clearDebugLocation();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _formatDebugTime(DateTime dt) {
    return '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
          // ── デバッグパネル ──
          if (_showDebugPanel && _state.hasPlan)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: theme.colorScheme.tertiaryContainer,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 時刻行
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _state.debugNow != null
                              ? _formatDebugTime(_state.debugNow!)
                              : '実時刻',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 28,
                        child: TextButton(
                          onPressed: _pickDebugTime,
                          child: const Text('変更', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                  // 位置行
                  Row(
                    children: [
                      const Icon(Icons.place, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _state.hasDebugLocation
                              ? '${_state.debugLat!.toStringAsFixed(4)}, ${_state.debugLng!.toStringAsFixed(4)}'
                              : '実際の現在地',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 28,
                        child: TextButton(
                          onPressed: _pickDebugLocation,
                          child: const Text('変更', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // チェック実行 + リセット
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: FilledButton.icon(
                            onPressed: _state.status == TripStatus.loading
                                ? null
                                : () => _state.debugPerformCheck(),
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: const Text('破綻チェック実行', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        child: OutlinedButton(
                          onPressed: () => _state.clearDebugOverrides(),
                          child: const Text('リセット', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

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
                    debugNow: _state.debugNow,
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
