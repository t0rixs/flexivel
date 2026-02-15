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

  // ── デバッグ用オーバーライド（時刻・位置） ──
  DateTime? _debugNow;
  DateTime? get debugNow => _debugNow;
  double? _debugLat;
  double? _debugLng;
  double? get debugLat => _debugLat;
  double? get debugLng => _debugLng;
  bool get hasDebugLocation => _debugLat != null && _debugLng != null;

  /// デバッグ用: 現在時刻を上書き
  void setDebugTime(DateTime time) {
    _debugNow = time;
    debugPrint('[DEBUG] 時刻を ${time.toIso8601String()} に設定');
    notifyListeners();
  }

  /// デバッグ用: 現在地を上書き
  void setDebugLocation(double lat, double lng) {
    _debugLat = lat;
    _debugLng = lng;
    debugPrint('[DEBUG] 位置を ($lat, $lng) に設定');
    notifyListeners();
  }

  /// デバッグ位置をクリアして実位置に戻す
  void clearDebugLocation() {
    _debugLat = null;
    _debugLng = null;
    notifyListeners();
  }

  /// デバッグ設定をすべてクリアして実時刻・実位置に戻す
  void clearDebugOverrides() {
    _debugNow = null;
    _debugLat = null;
    _debugLng = null;
    notifyListeners();
  }

  /// デバッグ用: 強制チェック実行（クールダウン無視）
  Future<void> debugPerformCheck() async {
    _applyCooldownUntil = null;
    await performCheck(force: true);
  }

  /// アプリ内で使う「現在時刻」（デバッグ時刻があればそれを使う）
  DateTime get effectiveNow => _debugNow ?? DateTime.now();

  // ── 15分タイマー / 出発時刻 ──
  Timer? _checkTimer;
  Timer? _departureTimer; // 出発時刻まで待つタイマー
  static const _checkInterval = Duration(minutes: 15);
  DateTime? _departureTime;
  DateTime? get departureTime => _departureTime;

  /// 出発時刻を設定。未来なら出発時刻に定期チェックを開始、過去なら即開始。
  void setDepartureTime(DateTime time) {
    _departureTime = time;
    notifyListeners();
  }

  // ── Firestore リアルタイム同期 ──
  StreamSubscription<Plan?>? _planSubscription;
  StreamSubscription<LastBroken?>? _lastBrokenSubscription;
  String? _lastProcessedBrokenCreatedAt; // 処理済み lastBroken の createdAt（重複防止）
  DateTime? _initTime; // アプリ起動時刻（古い lastBroken を無視するため）
  DateTime? _applyCooldownUntil; // applyChoice 後のクールダウン（再破綻ループ防止）

  // ────────────────────────────────────────────
  // 起動時: Firestore から plan を読み込み + リアルタイム同期
  // ────────────────────────────────────────────
  Future<void> initialize() async {
    _initTime = DateTime.now();

    // 1回取得（高速表示用）
    _plan = await _firestore.fetchPlan(userId);
    notifyListeners();

    // リアルタイム同期（バックエンドが plan を更新したら自動反映）
    _planSubscription = _firestore.planStream(userId).listen((plan) {
      _plan = plan;
      notifyListeners();
    });

    // lastBroken 監視（破綻通知: enrichPlan 後の check や /check で保存されたものを即時表示）
    // ・同じ createdAt の lastBroken は1度だけ処理する（Firestore 再接続時の重複防止）
    // ・アプリ起動前の古い lastBroken は無視する
    // ・applyChoice 後のクールダウン中は無視する
    _lastBrokenSubscription =
        _firestore.lastBrokenStream(userId).listen((lastBroken) {
      if (lastBroken != null && hasPlan) {
        // 処理済み → スキップ
        if (_lastProcessedBrokenCreatedAt == lastBroken.createdAt) {
          return;
        }
        // アプリ起動前の古い lastBroken → 無視
        final brokenTime = DateTime.tryParse(lastBroken.createdAt);
        if (brokenTime != null && _initTime != null && brokenTime.isBefore(_initTime!)) {
          debugPrint('[破綻通知] 古い lastBroken を無視: ${lastBroken.createdAt}');
          _lastProcessedBrokenCreatedAt = lastBroken.createdAt;
          return;
        }
        // applyChoice 後のクールダウン中 → 無視
        if (_applyCooldownUntil != null && DateTime.now().isBefore(_applyCooldownUntil!)) {
          debugPrint('[破綻通知] クールダウン中のため無視');
          _lastProcessedBrokenCreatedAt = lastBroken.createdAt;
          return;
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
    _departureTimer?.cancel();

    if (_departureTime != null && _departureTime!.isAfter(DateTime.now())) {
      // 出発時刻が未来 → その時刻まで待ってから開始
      final delay = _departureTime!.difference(DateTime.now());
      debugPrint('[check] 出発時刻まで ${delay.inMinutes}分待機');
      _departureTimer = Timer(delay, () {
        _startCheckLoop();
      });
    } else {
      // 出発時刻が過去 or 未設定 → 即開始
      _startCheckLoop();
    }
  }

  void _startCheckLoop() {
    performCheck();
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(_checkInterval, (_) => performCheck());
  }

  void stopPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _departureTimer?.cancel();
    _departureTimer = null;
  }

  // ────────────────────────────────────────────
  // §5.1: /check を呼び status に応じて分岐
  // ────────────────────────────────────────────
  Future<void> performCheck({bool force = false}) async {
    // applyChoice 後のクールダウン中はチェックしない（force=true で強制実行）
    if (!force && _applyCooldownUntil != null && DateTime.now().isBefore(_applyCooldownUntil!)) {
      debugPrint('[check] クールダウン中のためスキップ');
      return;
    }
    try {
      _status = TripStatus.loading;
      notifyListeners();

      final double lat;
      final double lng;
      if (hasDebugLocation) {
        lat = _debugLat!;
        lng = _debugLng!;
      } else {
        final position = await _location.getCurrentPosition();
        lat = position.latitude;
        lng = position.longitude;
      }
      final now = effectiveNow.toIso8601String();

      final response = await _api.check(
        CheckRequest(
          userId: userId,
          context: CheckRequestContext(
            now: now,
            currentLat: lat,
            currentLng: lng,
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

      // broken 状態をクリア + 定期チェック停止（再破綻ループ防止）
      _status = TripStatus.idle;
      _brokenTargetItemId = null;
      _brokenOptions = null;
      _errorMessage = null;
      // 60秒間クールダウン: この間は新しい broken を無視
      _applyCooldownUntil = DateTime.now().add(const Duration(seconds: 60));
      stopPeriodicCheck();
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
    _departureTimer?.cancel();
    _planSubscription?.cancel();
    _lastBrokenSubscription?.cancel();
    super.dispose();
  }
}
