import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../state/trip_state.dart';
import '../widgets/place_autocomplete_field.dart';

/// 予定作成画面
/// ユーザーが場所名・到着時刻・滞在時間を入力し /enrich-plan で保存する。
class PlanInputScreen extends StatefulWidget {
  const PlanInputScreen({super.key, required this.tripState});
  final TripState tripState;

  @override
  State<PlanInputScreen> createState() => _PlanInputScreenState();
}

class _PlanInputScreenState extends State<PlanInputScreen> {
  final List<_PlanItemEntry> _entries = [];
  bool _isSaving = false;

  /// 選択された日程（複数日対応）。未選択時は今日のみ。
  List<DateTime> _selectedDates = [];

  @override
  void initState() {
    super.initState();
    _selectedDates = [_dateOnly(DateTime.now())];
    // 最低3件（出発地 + 予定1件 + 宿/ゴール）
    _addEntry(hint: '出発地点');
    _addEntry(hint: '予定 1');
    _addEntry(hint: '宿 / ゴール');
  }

  DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  String _formatDate(DateTime d) =>
      '${d.month}月${d.day}日';

  /// ローカル DateTime をタイムゾーン付き ISO 8601 に変換。
  /// toIso8601String() はオフセットを含まないため、バックエンドで正しく解釈されない場合がある。
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

  void _addEntry({String? hint}) {
    _entries.add(_PlanItemEntry(hint: hint));
    if (mounted) setState(() {});
  }

  void _removeEntry(int index) {
    if (_entries.length <= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最低3件の予定が必要です')),
      );
      return;
    }
    setState(() => _entries.removeAt(index));
  }

  /// 入力をバリデーションし、_insertIndex の位置に1件追加
  void _insertItem(int afterIndex) {
    final insertAt = afterIndex + 1;
    _entries.insert(
      insertAt,
      _PlanItemEntry(hint: '予定 ${_entries.length - 1}'),
    );
    setState(() {});
  }

  Future<void> _save() async {
    // バリデーション
    for (int i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (e.nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${i + 1}番目の場所名を入力してください')),
        );
        return;
      }
      // 出発地は到着時刻を入力しない
      if (i > 0 && e.selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${i + 1}番目の時刻を選択してください')),
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

      // 出発地は到着時刻を入力しない → 2番目の予定の日付・時刻の10分前に出発とする
      final dateTime = i == 0
          ? () {
              final secondDayIdx =
                  _entries[1]!.selectedDayIndex.clamp(0, dates.length - 1);
              final secondDate = dates[secondDayIdx];
              return _entries[1]!.selectedTime != null
                  ? DateTime(
                      secondDate.year, secondDate.month, secondDate.day,
                      _entries[1]!.selectedTime!.hour,
                      _entries[1]!.selectedTime!.minute,
                    ).subtract(const Duration(minutes: 10))
                  : DateTime(
                      secondDate.year, secondDate.month, secondDate.day, 8, 0);
            }()
          : DateTime(
              baseDate.year, baseDate.month, baseDate.day,
              e.selectedTime!.hour, e.selectedTime!.minute,
            );
      items.add(EnrichPlanItemInput(
        id: 'item_$i',
        name: e.nameController.text.trim(),
        startTime: _toIso8601WithOffset(dateTime),
        stayMinutes: (i == 0 || i == _entries.length - 1) ? 0 : e.stayMinutes,
        placeId: e.selectedPlaceId,
      ));
    }

    final success = await widget.tripState.createPlan(items);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('旅程を作成'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 日程選択
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDates.length == 1
                            ? _formatDate(_selectedDates.first)
                            : '${_formatDate(_selectedDates.first)} 〜 ${_formatDate(_selectedDates.last)}'
                                '（${_selectedDates.length}日間）',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    _PlanItemCard(
                      index: index,
                      entry: _entries[index],
                      selectedDates: _selectedDates,
                      canRemove: _entries.length > 3,
                      onRemove: () => _removeEntry(index),
                      isFirst: index == 0,
                      isLast: index == _entries.length - 1,
                      apiService: widget.tripState.apiService,
                    ),
                    // 「＋」ボタン（末尾以外のアイテム間に表示）
                    if (index < _entries.length - 1)
                      _AddItemButton(onTap: () => _insertItem(index)),
                  ],
                );
              },
            ),
          ),
          // 保存ボタン
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
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
                      : const Text('保存して開始', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 1件分のエントリデータ ──
class _PlanItemEntry {
  _PlanItemEntry({this.hint});
  final String? hint;
  final nameController = TextEditingController();
  TimeOfDay? selectedTime;
  int stayMinutes = 30;
  int selectedDayIndex = 0; // 何日目か（0始まり）
  String? selectedPlaceId; // オートコンプリートで選択した場合
  String? _lastSelectedFullText; // 選択時の全文（手動編集で変わったら placeId をクリア）
}

// ── 1件分のカード UI ──
class _PlanItemCard extends StatefulWidget {
  const _PlanItemCard({
    required this.index,
    required this.entry,
    required this.selectedDates,
    required this.canRemove,
    required this.onRemove,
    required this.isFirst,
    required this.isLast,
    required this.apiService,
  });
  final int index;
  final _PlanItemEntry entry;
  final List<DateTime> selectedDates;
  final bool canRemove;
  final VoidCallback onRemove;
  final bool isFirst;
  final bool isLast;
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
    if (e._lastSelectedFullText != null && e.nameController.text != e._lastSelectedFullText) {
      e.selectedPlaceId = null;
      e._lastSelectedFullText = null;
    }
  }

  void _onPlaceSelected(PlaceAutocompletePrediction p) {
    widget.entry.selectedPlaceId = p.placeId;
    widget.entry._lastSelectedFullText = p.fullText;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: widget.entry.selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => widget.entry.selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = widget.entry;
    final label = widget.isFirst
        ? '出発地'
        : widget.isLast
            ? 'ゴール'
            : '予定 ${widget.index}';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダ
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    '${widget.index + 1}',
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
            // 場所名（オートコンプリート）
            PlaceAutocompleteField(
              controller: e.nameController,
              apiService: widget.apiService,
              hintText: e.hint ?? '場所名',
              onSelected: _onPlaceSelected,
            ),
            // 複数日の場合：何日目か選択
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
            // 出発地は到着時刻を入力しない
            if (!widget.isFirst) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '到着時刻',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.schedule, size: 20),
                        ),
                        child: Text(
                          e.selectedTime != null
                              ? '${e.selectedTime!.hour.toString().padLeft(2, '0')}:${e.selectedTime!.minute.toString().padLeft(2, '0')}'
                              : '選択',
                          style: e.selectedTime != null
                              ? null
                              : TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                  // ゴールは滞在時間不要
                  if (!widget.isLast) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<int>(
                        value: e.stayMinutes,
                        decoration: const InputDecoration(
                          labelText: '滞在',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [0, 15, 30, 45, 60, 90, 120]
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text('$m分'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => e.stayMinutes = v);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 予定追加ボタン ──
class _AddItemButton extends StatelessWidget {
  const _AddItemButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Center(
        child: IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.add_circle_outline, size: 28),
          color: Theme.of(context).colorScheme.primary,
          tooltip: '予定を追加',
        ),
      ),
    );
  }
}
