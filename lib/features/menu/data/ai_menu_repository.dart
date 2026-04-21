import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';

class MenuSuggestion {
  final String name;
  final String description;
  final int suggestedPriceXaf;
  final List<String> allergens;
  final int preparationTimeMin;
  final String category;
  final String? matchedDish;

  MenuSuggestion({
    required this.name,
    required this.description,
    required this.suggestedPriceXaf,
    required this.allergens,
    required this.preparationTimeMin,
    required this.category,
    required this.matchedDish,
  });

  factory MenuSuggestion.fromJson(Map<String, dynamic> json) {
    return MenuSuggestion(
      name: (json['name'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      suggestedPriceXaf: (json['suggestedPriceXaf'] ?? 0) as int,
      allergens: (json['allergens'] is List)
          ? (json['allergens'] as List).map((e) => e.toString()).toList()
          : <String>[],
      preparationTimeMin: (json['preparationTimeMin'] ?? 20) as int,
      category: (json['category'] ?? 'plat') as String,
      matchedDish: json['matchedDish'] as String?,
    );
  }
}

class AiMenuRepository {
  final _client = ApiClient.instance;

  Future<MenuSuggestion> suggest({
    required String dishKeywords,
    String? category,
  }) async {
    try {
      final response = await _client.post(
        ApiConstants.aiMenuSuggest,
        data: {
          'dishKeywords': dishKeywords,
          if (category != null) 'category': category,
          'cuisineContext': 'camerounaise',
        },
      );
      final body = response.data;
      final json = body is Map && body['data'] is Map
          ? body['data'] as Map<String, dynamic>
          : body as Map<String, dynamic>;
      return MenuSuggestion.fromJson(json);
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }
}
