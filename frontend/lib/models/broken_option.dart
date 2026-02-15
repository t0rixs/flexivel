import 'detour_candidate.dart';

/// 仕様書_データモデルに基づく broken 時の3択（GO_NEXT / DETOUR / SKIP）
sealed class BrokenOption {
  const BrokenOption();
  String get kind;
  String get reason;

  factory BrokenOption.fromJson(Map<String, dynamic> json) {
    final kind = json['kind'] as String;
    final reason = json['reason'] as String? ?? '';
    switch (kind) {
      case 'GO_NEXT':
        return BrokenOptionGoNext(reason: reason);
      case 'DETOUR':
        final candidates = (json['candidates'] as List<dynamic>)
            .map((e) => DetourCandidate.fromJson(e as Map<String, dynamic>))
            .toList();
        return BrokenOptionDetour(reason: reason, candidates: candidates);
      case 'SKIP':
        return BrokenOptionSkip(reason: reason);
      default:
        throw ArgumentError('Unknown BrokenOption kind: $kind');
    }
  }

  Map<String, dynamic> toJson() {
    return switch (this) {
      BrokenOptionGoNext(:final reason) => {'kind': 'GO_NEXT', 'reason': reason},
      BrokenOptionDetour(:final reason, :final candidates) => {
          'kind': 'DETOUR',
          'reason': reason,
          'candidates': candidates.map((e) => e.toJson()).toList(),
        },
      BrokenOptionSkip(:final reason) => {'kind': 'SKIP', 'reason': reason},
    };
  }
}

class BrokenOptionGoNext extends BrokenOption {
  BrokenOptionGoNext({required this.reason});
  @override
  final String kind = 'GO_NEXT';
  @override
  final String reason;
}

class BrokenOptionDetour extends BrokenOption {
  BrokenOptionDetour({
    required this.reason,
    required this.candidates,
  });
  @override
  final String kind = 'DETOUR';
  @override
  final String reason;
  final List<DetourCandidate> candidates; // 3件
}

class BrokenOptionSkip extends BrokenOption {
  BrokenOptionSkip({required this.reason});
  @override
  final String kind = 'SKIP';
  @override
  final String reason;
}
