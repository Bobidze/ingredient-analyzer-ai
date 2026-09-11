import 'package:flutter/material.dart';

/// Уровень внимания к ингредиенту.
/// Значения совпадают со строками, которые возвращает Gemini
/// (см. responseSchema в [GeminiService]).
enum ConcernLevel {
  safe,
  moderate,
  avoid;

  /// Разбор строки из ответа модели. Неизвестные значения
  /// трактуем как [moderate], чтобы не падать на неожиданных данных.
  factory ConcernLevel.fromApi(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'safe':
        return ConcernLevel.safe;
      case 'avoid':
        return ConcernLevel.avoid;
      case 'moderate':
      default:
        return ConcernLevel.moderate;
    }
  }

  /// Цвет полосы-индикатора слева на карточке.
  Color get color => switch (this) {
        ConcernLevel.safe => const Color(0xFF2E9E5B),
        ConcernLevel.moderate => const Color(0xFFE0A000),
        ConcernLevel.avoid => const Color(0xFFD1483C),
      };

  /// Человекочитаемая подпись для UI.
  String get label => switch (this) {
        ConcernLevel.safe => 'Безопасен',
        ConcernLevel.moderate => 'Есть нюансы',
        ConcernLevel.avoid => 'Стоит избегать',
      };

  IconData get icon => switch (this) {
        ConcernLevel.safe => Icons.check_circle_outline,
        ConcernLevel.moderate => Icons.info_outline,
        ConcernLevel.avoid => Icons.warning_amber_rounded,
      };
}

/// Один разобранный ингредиент состава.
@immutable
class Ingredient {
  const Ingredient({
    required this.name,
    required this.category,
    required this.purpose,
    required this.concernLevel,
    required this.note,
  });

  /// Название (например, «Бензоат натрия»).
  final String name;

  /// Категория: консервант, краситель, эмульгатор, витамин и т.д.
  final String category;

  /// Зачем он нужен в продукте.
  final String purpose;

  /// Итоговый уровень внимания.
  final ConcernLevel concernLevel;

  /// Короткое пояснение / нюанс.
  final String note;

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Без названия',
      category: (json['category'] as String?)?.trim() ?? '—',
      purpose: (json['purpose'] as String?)?.trim() ?? '',
      concernLevel: ConcernLevel.fromApi(json['concern_level'] as String?),
      note: (json['note'] as String?)?.trim() ?? '',
    );
  }
}
