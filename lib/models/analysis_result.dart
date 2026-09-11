import 'package:flutter/material.dart';

import 'ingredient.dart';

/// Результат разбора состава продукта, полученный от Gemini.
@immutable
class AnalysisResult {
  const AnalysisResult({
    required this.productSummary,
    required this.overallScore,
    required this.ingredients,
  });

  /// Общая текстовая оценка продукта.
  final String productSummary;

  /// Итоговая оценка от 1 до 10.
  final int overallScore;

  /// Список разобранных ингредиентов.
  final List<Ingredient> ingredients;

  /// Разбор корневого JSON-объекта, который вернула модель.
  /// Все поля читаются защитно: отсутствие или неверный тип не роняет парсинг.
  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawScore = json['overall_score'];
    final score = switch (rawScore) {
      final int v => v,
      final double v => v.round(),
      final String v => int.tryParse(v) ?? 0,
      _ => 0,
    };

    final rawList = json['ingredients'];
    final ingredients = <Ingredient>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          ingredients.add(Ingredient.fromJson(item));
        }
      }
    }

    return AnalysisResult(
      productSummary:
          (json['product_summary'] as String?)?.trim() ?? 'Оценка недоступна',
      overallScore: score.clamp(1, 10),
      ingredients: ingredients,
    );
  }

  /// Цвет для общей оценки: 1–4 красный, 5–7 жёлтый, 8–10 зелёный.
  Color get scoreColor {
    if (overallScore >= 8) return const Color(0xFF2E9E5B);
    if (overallScore >= 5) return const Color(0xFFE0A000);
    return const Color(0xFFD1483C);
  }
}
