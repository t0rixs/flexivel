import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/last_broken.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/firestore_service.dart';

/// 仕様書_API仕様 §5: クライアント挙動（状態遷移）
///
/// 状態:
///   - idle (ok): 通常状態
///   - warn: 締切接近の警告
///   - broken: 旅程破綻 → 3択表示
///   - loading: API通信中
enum TripStatus { idle, warn, broken, loading }

class TripState extends ChangeNotifier {
  TripState({
    required this.userId,
    ApiService? apiService,
    LocationService? locationService,
    FirestoreUserService? firestoreService,
  })  : _api = apiService ?? ApiService(),
        _location = locationService ?? LocationService(),
        _firestore = firestoreService ?? FirestoreUserService();

  final String userId;
  final ApiService _api;
  ApiService get apiService => _api;
  final LocationService _location;
  final FirestoreUserService _firestore;

  // ── 状態 ──
  TripStatus _status = TripStatus.idle;
  TripStatus get status => _status;

  Plan? _plan;
  Plan? get plan => _plan;

  bool get hasPlan => _plan != null && _plan!.items.isNotEmpty;

  // warn 用
  String? _warnTargetItemId;
  String? get warnTargetItemId => _warnTargetItemId;
  int? _minutesToDeadline;
  int? get minutesToDeadline => _minutesToDeadline;

  // broken 用
  String? _brokenTargetItemId;
  String? get brokenTargetItemId => _brokenTargetItemId;
  List<BrokenOption>? _brokenOptions;
  List<BrokenOption>? get brokenOptions => _brokenOptions;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ── 15分タイマー ──
  Timer? _checkTimer;
  static const _checkInterval = Duration(minutes: 15);

  // ── Firestore リアルタイム同期 ──
  StreamSubscription<Plan?>? _planSubscription;
  StreamSubscription<LastBroken?>? _lastBrokenSubscription;
  String? _lastProcessedBrokenCreatedAt; // 処理済み lastBroken の createdAt（重複防止）

  // ────────────────────────────────────────────
  // 起動時: Firestore から plan を読み込み + リアルタイム同期
  // ────────────────────────────────────────────
  Future<void> initialize() async {
    // 1回取得（高速表示用）
    _plan = await _firestore.fetchPlan(userId);
    notifyListeners();

    // リアルタイム同期（バックエンドが plan を更新したら自動反映）
    _planSubscription = _firestore.planStream(userId).listen((plan) {
      _plan = plan;
      notifyListeners();
    });

    // lastBroken 監視（破綻通知: enrichPlan 後の check や /check で保存されたものを即時表示）
    // 同じ createdAt の lastBroken は1度だけ処理する（Firestore 再接続時の重複防止）
    _lastBrokenSubscription =
        _firestore.lastBrokenStream(userId).listen((lastBroken) {
      if (lastBroken != null && hasPlan) {
        if (_lastProcessedBrokenCreatedAt == lastBroken.createdAt) {
          return; // 処理済み → スキップ
        }
        debugPrint(
            '[破綻通知] Firestore lastBroken 受信: targetItemId=${lastBroken.targetItemId}');
        _lastProcessedBrokenCreatedAt = lastBroken.createdAt;
        _status = TripStatus.broken;
        _brokenTargetItemId = lastBroken.targetItemId;
        _brokenOptions = lastBroken.options;
        _warnTargetItemId = null;
        _minutesToDeadline = null;
      } else if (lastBroken == null) {
        _lastProcessedBrokenCreatedAt = null;
        _brokenTargetItemId = null;
        _brokenOptions = null;
        if (_status == TripStatus.broken) {
          _status = TripStatus.idle;
        }
      }
      notifyListeners();
    });
  }

  // ────────────────────────────────────────────
  // §5.1: 定期チェック開始 / 停止
  // ────────────────────────────────────────────
  void startPeriodicCheck() {
    // 即座に1回実行 + 15分おき
    performCheck();
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(_checkInterval, (_) => performCheck());
  }

  void stopPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  // ────────────────────────────────────────────
  // §5.1: /check を呼び status に応じて分岐
  // ────────────────────────────────────────────
  Future<void> performCheck() async {
    try {
      _status = TripStatus.loading;
      notifyListeners();

      final position = await _location.getCurrentPosition();
      final now = DateTime.now().toIso8601String();

      final response = await _api.check(
        CheckRequest(
          userId: userId,
          context: CheckRequestContext(
            now: now,
            currentLat: position.latitude,
            currentLng: position.longitude,
          ),
        ),
      );

      switch (response.status) {
        case 'ok':
          _status = TripStatus.idle;
          _warnTargetItemId = null;
          _minutesToDeadline = null;
          _brokenTargetItemId = null;
          _brokenOptions = null;

        case 'warn':
          _status = TripStatus.warn;
          _warnTargetItemId = response.targetItemId;
          _minutesToDeadline = response.minutesToDeadline;
          _brokenTargetItemId = null;
          _brokenOptions = null;

        case 'broken':
          debugPrint('[破綻通知] broken 受信: targetItemId=${response.targetItemId}, options=${response.options?.length ?? 0}件');
          _status = TripStatus.broken;
          _brokenTargetItemId = response.targetItemId;
          _brokenOptions = response.options;
          _warnTargetItemId = null;
          _minutesToDeadline = null;
      }

      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _status = TripStatus.idle;
    }
    notifyListeners();
  }

  // ────────────────────────────────────────────
  // §5.3: ユーザー選択 → /apply-option
  // ────────────────────────────────────────────
  Future<void> applyChoice(ApplyOptionChoice choice) async {
    if (_brokenTargetItemId == null) return;

    try {
      _status = TripStatus.loading;
      notifyListeners();

      final response = await _api.applyOption(
        ApplyOptionRequest(
          userId: userId,
          targetItemId: _brokenTargetItemId!,
          choice: choice,
        ),
      );

      // エラーレスポンスの処理
      if (response.status == 'error') {
        _errorMessage = response.message ?? '選択の適用に失敗しました。';
        _status = TripStatus.broken; // broken に戻して再選択を促す
        notifyListeners();
        return;
      }

      if (response.updatedPlan != null) {
        _plan = response.updatedPlan;
      }

      // broken 状態をクリアして次のチェックへ
      _status = TripStatus.idle;
      _brokenTargetItemId = null;
      _brokenOptions = null;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      _status = TripStatus.broken;
    }
    notifyListeners();
  }

  // ────────────────────────────────────────────
  // 予定作成: /enrich-plan を呼び plan を保存
  // ────────────────────────────────────────────
  Future<bool> createPlan(List<EnrichPlanItemInput> items) async {
    try {
      _status = TripStatus.loading;
      notifyListeners();

      final planId = 'plan_${DateTime.now().millisecondsSinceEpoch}';
      final response = await _api.enrichPlan(
        EnrichPlanRequest(
          userId: userId,
          plan: EnrichPlanRequestPlan(
            planId: planId,
            createdAt: DateTime.now().toIso8601String(),
            items: items,
          ),
        ),
      );

      if (response.status == 'ok' && response.plan != null) {
        _plan = response.plan;
        _errorMessage = null;
        _status = TripStatus.idle;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.message ?? '予定の保存に失敗しました。';
        _status = TripStatus.idle;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _status = TripStatus.idle;
      notifyListeners();
      return false;
    }
  }

  // ────────────────────────────────────────────
  // Plan の直接設定
  // ────────────────────────────────────────────
  void setPlan(Plan plan) {
    _plan = plan;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPeriodicCheck();
    _planSubscription?.cancel();
    _lastBrokenSubscription?.cancel();
    super.dispose();
  }
}
