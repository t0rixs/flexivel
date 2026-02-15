import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/last_broken.dart';
import '../models/models.dart';

/// Firestore から直接 plan を取得するサービス。
/// 起動時やリアルタイム同期で使用。
class FirestoreUserService {
  FirestoreUserService();

  final _firestore = FirebaseFirestore.instance;

  /// users/{userId} のドキュメント参照
  DocumentReference<Map<String, dynamic>> _userRef(String userId) =>
      _firestore.collection('users').doc(userId);

  /// 現在の plan を1回取得
  Future<Plan?> fetchPlan(String userId) async {
    final snap = await _userRef(userId).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null || data['plan'] == null) return null;
    return Plan.fromJson(data['plan'] as Map<String, dynamic>);
  }

  /// plan の変更をリアルタイムで受け取る Stream
  Stream<Plan?> planStream(String userId) {
    return _userRef(userId).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null || data['plan'] == null) return null;
      return Plan.fromJson(data['plan'] as Map<String, dynamic>);
    });
  }

  /// lastBroken の変更をリアルタイムで受け取る Stream（破綻通知用）
  Stream<LastBroken?> lastBrokenStream(String userId) {
    return _userRef(userId).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null || data['lastBroken'] == null) return null;
      return LastBroken.fromJson(
          data['lastBroken'] as Map<String, dynamic>);
    });
  }
}
