import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Places オートコンプリートのレスポンス
class PlacesAutocompleteResponse {
  PlacesAutocompleteResponse({required this.suggestions});
  final List<PlaceAutocompletePrediction> suggestions;

  factory PlacesAutocompleteResponse.fromJson(Map<String, dynamic> json) {
    final list = json['suggestions'] as List<dynamic>? ?? [];
    return PlacesAutocompleteResponse(
      suggestions: list
          .map((e) => PlaceAutocompletePrediction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 仕様書_API仕様 §1-4: バックエンド API との通信
class ApiService {
  ApiService({String? baseUrl}) : _baseUrl = baseUrl ?? _defaultBaseUrl();

  final String _baseUrl;

  /// プラットフォーム別のデフォルト API URL
  /// - Android エミュレータ: 10.0.2.2 がホストの localhost に対応
  /// - iOS シミュレータ / その他: localhost を使用
  /// - 環境変数 API_BASE_URL が設定されていればそちらを優先
  static String _defaultBaseUrl() {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return 'https://flexivel-backend-186244424243.asia-northeast1.run.app';
  }

  // ────────────────────────────────────────────
  // §2: POST /check
  // ────────────────────────────────────────────
  Future<CheckResponse> check(CheckRequest request) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/check'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException('POST /check failed: ${res.statusCode} ${res.body}');
    }
    return CheckResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  // ────────────────────────────────────────────
  // §3: POST /apply-option
  // ────────────────────────────────────────────
  Future<ApplyOptionResponse> applyOption(ApplyOptionRequest request) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/apply-option'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException(
          'POST /apply-option failed: ${res.statusCode} ${res.body}');
    }
    return ApplyOptionResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  // ────────────────────────────────────────────
  // Places オートコンプリート
  // ────────────────────────────────────────────
  Future<List<PlaceAutocompletePrediction>> placesAutocomplete(
    String input, {
    double? lat,
    double? lng,
  }) async {
    if (input.trim().length < 2) return [];

    final query = <String, String>{
      'input': input.trim(),
    };
    if (lat != null) query['lat'] = lat.toString();
    if (lng != null) query['lng'] = lng.toString();

    final uri = Uri.parse('$_baseUrl/places/autocomplete').replace(queryParameters: query);
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return PlacesAutocompleteResponse.fromJson(data).suggestions;
  }

  // ────────────────────────────────────────────
  // §4: POST /enrich-plan
  // ────────────────────────────────────────────
  Future<EnrichPlanResponse> enrichPlan(EnrichPlanRequest request) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/enrich-plan'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw ApiException(
          'POST /enrich-plan failed: ${res.statusCode} ${res.body}');
    }
    return EnrichPlanResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => 'ApiException: $message';
}
