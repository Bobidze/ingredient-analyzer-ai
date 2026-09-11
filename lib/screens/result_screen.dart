import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analysis_result.dart';
import '../providers/analysis_provider.dart';
import '../services/ai_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/ingredient_card.dart';
import '../widgets/loading_view.dart';

/// Экран результата: общая оценка сверху, ниже — карточки ингредиентов.
/// Все три состояния (loading / data / error) приходят из [AsyncValue].
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analysisControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Результат анализа')),
      body: SafeArea(
        child: state.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            message: _messageFor(error),
            icon: _iconFor(error),
            onRetry: () =>
                ref.read(analysisControllerProvider.notifier).retry(),
          ),
          data: (result) {
            if (result == null) {
              // На этот экран без результата попасть не должны.
              return const LoadingView();
            }
            return _ResultBody(result: result);
          },
        ),
      ),
    );
  }

  String _messageFor(Object error) => error is AiException
      ? error.message
      : 'Неизвестная ошибка. Попробуйте ещё раз.';

  IconData _iconFor(Object error) => switch (error) {
        NetworkException() => Icons.wifi_off_rounded,
        RequestTimeoutException() => Icons.timer_off_outlined,
        RateLimitException() => Icons.hourglass_bottom_rounded,
        _ => Icons.error_outline_rounded,
      };
}

class _ResultBody extends ConsumerWidget {
  const _ResultBody({required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              _ScoreHeader(result: result),
              const SizedBox(height: 24),
              if (result.ingredients.isEmpty)
                _EmptyIngredients()
              else ...[
                Text(
                  'Ингредиенты · ${result.ingredients.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                ...result.ingredients.map((i) => IngredientCard(ingredient: i)),
              ],
            ],
          ),
        ),
        _BottomBar(
          onNewAnalysis: () {
            ref.read(analysisControllerProvider.notifier).reset();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

/// Верхняя плашка с общей оценкой продукта.
class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = result.scoreColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScoreBadge(score: result.overallScore, color: color),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Общая оценка',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  result.productSummary,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.color});

  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$score',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const TextSpan(
              text: '/10',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyIngredients extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.search_off_rounded,
              size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'Ингредиенты не распознаны',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Попробуйте более чёткое фото или введите состав текстом.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onNewAnalysis});

  final VoidCallback onNewAnalysis;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onNewAnalysis,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Новый анализ'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }
}
