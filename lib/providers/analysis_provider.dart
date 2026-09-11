import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/ai_config.dart';
import '../models/analysis_result.dart';
import '../services/ai_provider.dart';

/// Активный LLM-провайдер на всё приложение (выбирается в [AiConfig]).
/// Закрываем http-клиент при уничтожении провайдера.
final aiProviderProvider = Provider<AiProvider>((ref) {
  final provider = AiConfig.createProvider();
  ref.onDispose(provider.dispose);
  return provider;
});

/// Контроллер анализа. Состояние — [AsyncValue]:
/// - `AsyncData(null)`  — простой (ничего ещё не анализировали);
/// - `AsyncLoading`     — идёт запрос;
/// - `AsyncData(result)`— готовый разбор;
/// - `AsyncError`       — ошибка (в error лежит [GeminiException]).
class AnalysisController extends AsyncNotifier<AnalysisResult?> {
  // Запоминаем последний запрос, чтобы кнопка «Повторить» работала
  // без возврата на экран ввода.
  String? _lastText;
  Uint8List? _lastImage;
  String _lastMime = 'image/jpeg';

  @override
  FutureOr<AnalysisResult?> build() => null; // стартуем в «простое»

  /// Запускает анализ. Нужно передать хотя бы одно из [text] / [imageBytes].
  Future<void> analyze({
    String? text,
    Uint8List? imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    _lastText = text;
    _lastImage = imageBytes;
    _lastMime = mimeType;
    await _run();
  }

  /// Повторяет последний запрос (кнопка «Повторить» на экране ошибки).
  Future<void> retry() => _run();

  Future<void> _run() async {
    state = const AsyncValue.loading();
    // guard ловит исключения сервиса и кладёт их в AsyncError,
    // сохраняя тип GeminiException для показа нужного сообщения.
    state = await AsyncValue.guard(() {
      return ref.read(aiProviderProvider).analyzeIngredients(
            text: _lastText,
            imageBytes: _lastImage,
            mimeType: _lastMime,
          );
    });
  }

  /// Возврат в исходное состояние — для кнопки «Новый анализ».
  void reset() {
    _lastText = null;
    _lastImage = null;
    state = const AsyncValue.data(null);
  }
}

final analysisControllerProvider =
    AsyncNotifierProvider<AnalysisController, AnalysisResult?>(
  AnalysisController.new,
);
