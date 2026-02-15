import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../state/trip_state.dart';
import '../widgets/place_autocomplete_field.dart';

/// 予定作成画面
/// ユーザーが場所名・開始時刻・終了時刻を入力し /enrich-plan で保存する。
class PlanInputScreen extends StatefulWidget {
  const PlanInputScreen({super.key, required this.tripState});
  final TripState tripState;

  @override
  State<PlanInputScreen> createState() => _PlanInputScreenState();
}

class _PlanInputScreenState extends State<PlanInputScreen> {
  final List<_PlanItemEntry> _entries = [];
  bool _isSaving = false;
  TimeOfDay? _departureTime; // 出発時刻（15分チェックの開始時間）

  /// 選択された日程（複数日対応）。未選択時は今日のみ。
  List<DateTime> _selectedDates = [];

  @override
  void initState() {
    super.initState();
    _selectedDates = [_dateOnly(DateTime.now())];
    // 初期: 予定1 + 終了地点
    _entries.add(_PlanItemEntry());
    _entries.add(_PlanItemEntry(isEndPoint: true));
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _formatDate(DateTime d) => '${d.month}月${d.day}日';

  /// ローカル DateTime をタイムゾーン付き ISO 8601 に変換。
  String _toIso8601WithOffset(DateTime dt) {
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final mins = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final offsetStr = '$sign$hours:$mins';
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
        'T${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}$offsetStr';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = _selectedDates.isEmpty
        ? DateTimeRange(start: now, end: now)
        : DateTimeRange(
            start: _selectedDates.first,
            end: _selectedDates.length > 1
                ? _selectedDates.last
                : _selectedDates.first,
          );
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: initialRange,
    );
    if (range != null && mounted) {
      setState(() {
        _selectedDates = [];
        for (var d = range.start;
            !d.isAfter(range.end);
            d = d.add(const Duration(days: 1))) {
          _selectedDates.add(_dateOnly(d));
        }
      });
    }
  }

  /// 終了地点の手前に予定を追加
  void _addEntry() {
    // 終了地点（最後のエントリ）の直前に挿入
    final insertAt = _entries.length > 0 && _entries.last.isEndPoint
        ? _entries.length - 1
        : _entries.length;
    _entries.insert(insertAt, _PlanItemEntry());
    if (mounted) setState(() {});
  }

  void _insertEntry(int afterIndex) {
    _entries.insert(afterIndex + 1, _PlanItemEntry());
    setState(() {});
  }

  void _removeEntry(int index) {
    // 終了地点は削除不可
    if (_entries[index].isEndPoint) return;
    // 最低1件の予定（＋終了地点）は必要
    final normalCount = _entries.where((e) => !e.isEndPoint).length;
    if (normalCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最低1件の予定が必要です')),
      );
      return;
    }
    setState(() => _entries.removeAt(index));
  }

  Future<void> _pickDepartureTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _departureTime = picked);
    }
  }

  Future<void> _save() async {
    // バリデーション: 出発時刻
    if (_departureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('出発時刻を選択してください')),
      );
      return;
    }
    // バリデーション: 各予定
    for (int i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      final label = e.isEndPoint ? '終了地点' : '${i + 1}番目';
      if (e.nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$labelの場所名を入力してください')),
        );
        return;
      }
      if (e.startTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.isEndPoint
              ? '終了地点の到着時刻を選択してください'
              : '$labelの開始時刻を選択してください')),
        );
        return;
      }
      // 終了地点以外は終了時刻も必須
      if (!e.isEndPoint && e.endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$labelの終了時刻を選択してください')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final items = <EnrichPlanItemInput>[];
    final dates = _selectedDates.isEmpty
        ? [_dateOnly(DateTime.now())]
        : _selectedDates;

    for (int i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      final dayIdx = e.selectedDayIndex.clamp(0, dates.length - 1);
      final baseDate = dates[dayIdx];

      final startDt = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        e.startTime!.hour,
        e.startTime!.minute,
      );

      // stayMinutes = 終了時刻 − 開始時刻（分）。終了地点は滞在0分。
      int stay;
      if (e.isEndPoint || e.endTime == null) {
        stay = 0;
      } else {
        final startMin = e.startTime!.hour * 60 + e.startTime!.minute;
        final endMin = e.endTime!.hour * 60 + e.endTime!.minute;
        stay = endMin - startMin;
        if (stay < 0) stay += 24 * 60; // 日跨ぎ対応
        if (stay == 0) stay = 30; // 同じ時刻の場合のフォールバック
      }

      items.add(EnrichPlanItemInput(
        id: 'item_$i',
        name: e.nameController.text.trim(),
        startTime: _toIso8601WithOffset(startDt),
        stayMinutes: stay,
        placeId: e.selectedPlaceId,
      ));
    }

    final success = await widget.tripState.createPlan(items);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      // 出発時刻を TripState に保存（定期チェック開始のスケジュール用）
      final depDates = _selectedDates.isEmpty
          ? [_dateOnly(DateTime.now())]
          : _selectedDates;
      final depDate = depDates.first;
      final depDateTime = DateTime(
        depDate.year,
        depDate.month,
        depDate.day,
        _departureTime!.hour,
        _departureTime!.minute,
      );
      widget.tripState.setDepartureTime(depDateTime);
      Navigator.of(context).pop(true); // 成功 → 前の画面に戻る
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.tripState.errorMessage ?? '保存に失敗しました'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('旅程を作成'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── 日程選択 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDates.length == 1
                            ? _formatDate(_selectedDates.first)
                            : '${_formatDate(_selectedDates.first)} 〜 ${_formatDate(_selectedDates.last)}'
                                '（${_selectedDates.length}日間）',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          // ── 出発時刻 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: InkWell(
              onTap: _pickDepartureTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.departure_board,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _departureTime != null
                            ? '出発 ${_fmtTod(_departureTime!)}'
                            : '出発時刻を選択',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: _departureTime != null
                              ? null
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          // ── 予定リスト ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              // カード N 枚 + 間の「＋」ボタン（終了地点の後は除く）
              itemCount: _entries.length * 2 - 1,
              itemBuilder: (context, i) {
                // 偶数: 予定カード、奇数: 追加ボタン
                if (i.isEven) {
                  final idx = i ~/ 2;
                  final entry = _entries[idx];
                  final normalCount =
                      _entries.where((e) => !e.isEndPoint).length;
                  return _PlanItemCard(
                    index: idx,
                    entry: entry,
                    selectedDates: _selectedDates,
                    canRemove: !entry.isEndPoint && normalCount > 1,
                    onRemove: () => _removeEntry(idx),
                    apiService: widget.tripState.apiService,
                  );
                } else {
                  final afterIdx = i ~/ 2;
                  return _InsertButton(onTap: () => _insertEntry(afterIdx));
                }
              },
            ),
          ),
          // ── 末尾の追加ボタン + 保存ボタン ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: _addEntry,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('予定を追加'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('保存して開始',
                              style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ── 1件分のエントリデータ ──
class _PlanItemEntry {
  _PlanItemEntry({this.isEndPoint = false});
  final bool isEndPoint; // 終了地点フラグ
  final nameController = TextEditingController();
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  int selectedDayIndex = 0; // 何日目か（0始まり）
  String? selectedPlaceId;
  String? _lastSelectedFullText;
}

// ── タイムライン風の予定カード ──
class _PlanItemCard extends StatefulWidget {
  const _PlanItemCard({
    required this.index,
    required this.entry,
    required this.selectedDates,
    required this.canRemove,
    required this.onRemove,
    required this.apiService,
  });
  final int index;
  final _PlanItemEntry entry;
  final List<DateTime> selectedDates;
  final bool canRemove;
  final VoidCallback onRemove;
  final ApiService apiService;

  @override
  State<_PlanItemCard> createState() => _PlanItemCardState();
}

class _PlanItemCardState extends State<_PlanItemCard> {
  @override
  void initState() {
    super.initState();
    widget.entry.nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    widget.entry.nameController.removeListener(_onNameChanged);
    super.dispose();
  }

  void _onNameChanged() {
    final e = widget.entry;
    if (e._lastSelectedFullText != null &&
        e.nameController.text != e._lastSelectedFullText) {
      e.selectedPlaceId = null;
      e._lastSelectedFullText = null;
    }
  }

  void _onPlaceSelected(PlaceAutocompletePrediction p) {
    widget.entry.selectedPlaceId = p.placeId;
    widget.entry._lastSelectedFullText = p.fullText;
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: widget.entry.startTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => widget.entry.startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final initial =
        widget.entry.endTime ?? widget.entry.startTime ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => widget.entry.endTime = picked);
    }
  }

  static String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.entry;
    final isEnd = e.isEndPoint;

    // ラベル: 通常予定は「予定 N」、終了地点は「終了地点」
    final label = isEnd ? '終了地点' : '予定 ${widget.index + 1}';
    final avatarIcon = isEnd ? Icons.flag : null;
    final avatarText = isEnd ? null : '${widget.index + 1}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ヘッダ: 番号/アイコン + ラベル + 削除ボタン ──
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isEnd
                      ? theme.colorScheme.tertiaryContainer
                      : theme.colorScheme.primaryContainer,
                  child: avatarIcon != null
                      ? Icon(avatarIcon, size: 14,
                          color: theme.colorScheme.onTertiaryContainer)
                      : Text(
                          avatarText!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Text(label, style: theme.textTheme.labelLarge),
                const Spacer(),
                if (widget.canRemove)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onRemove,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // ── 時刻入力 ──
            if (isEnd)
              // 終了地点: 到着時刻のみ
              InkWell(
                onTap: _pickStartTime,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '到着時刻',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.schedule, size: 20),
                  ),
                  child: Text(
                    e.startTime != null ? _fmtTod(e.startTime!) : '選択',
                    style: e.startTime != null
                        ? null
                        : TextStyle(
                            color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              // 通常予定: 開始時刻 → 終了時刻
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickStartTime,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '開始時刻',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.play_arrow, size: 20),
                        ),
                        child: Text(
                          e.startTime != null ? _fmtTod(e.startTime!) : '選択',
                          style: e.startTime != null
                              ? null
                              : TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _pickEndTime,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '終了時刻',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.stop, size: 20),
                        ),
                        child: Text(
                          e.endTime != null ? _fmtTod(e.endTime!) : '選択',
                          style: e.endTime != null
                              ? null
                              : TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),

            // ── 場所名（オートコンプリート） ──
            PlaceAutocompleteField(
              controller: e.nameController,
              apiService: widget.apiService,
              hintText: isEnd ? '終了地点の場所名' : '場所名を入力',
              onSelected: _onPlaceSelected,
            ),

            // ── 複数日の場合: 日程選択 ──
            if (widget.selectedDates.length > 1) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: widget.entry.selectedDayIndex
                    .clamp(0, widget.selectedDates.length - 1),
                decoration: const InputDecoration(
                  labelText: '日程',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: List.generate(
                  widget.selectedDates.length,
                  (i) {
                    final d = widget.selectedDates[i];
                    return DropdownMenuItem(
                      value: i,
                      child: Text('${i + 1}日目 (${d.month}/${d.day})'),
                    );
                  },
                ),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => widget.entry.selectedDayIndex = v);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 予定の間に挿入する「＋」ボタン ──
class _InsertButton extends StatelessWidget {
  const _InsertButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        onPressed: onTap,
        icon: const Icon(Icons.add_circle_outline, size: 24),
        color: Theme.of(context).colorScheme.primary,
        tooltip: '間に予定を追加',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(vertical: 2),
        constraints: const BoxConstraints(minHeight: 28),
      ),
    );
  }
}
