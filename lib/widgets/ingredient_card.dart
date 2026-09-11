import 'package:flutter/material.dart';

import '../models/ingredient.dart';

/// Карточка одного ингредиента с цветной полосой-индикатором слева.
class IngredientCard extends StatelessWidget {
  const IngredientCard({super.key, required this.ingredient});

  final Ingredient ingredient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = ingredient.concernLevel;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Цветная полоса: зелёная / жёлтая / красная.
            Container(width: 6, color: level.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            ingredient.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ConcernBadge(level: level),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _CategoryChip(category: ingredient.category, color: level.color),
                    if (ingredient.purpose.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        ingredient.purpose,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    if (ingredient.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        ingredient.note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Значок уровня внимания (иконка + подпись) в цвет полосы.
class _ConcernBadge extends StatelessWidget {
  const _ConcernBadge({required this.level});

  final ConcernLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: 15, color: level.color),
          const SizedBox(width: 5),
          Text(
            level.label,
            style: TextStyle(
              color: level.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.color});

  final String category;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      category.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
