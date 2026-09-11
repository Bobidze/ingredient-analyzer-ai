import '../services/ai_provider.dart';
import '../services/openai_provider.dart';
import '../services/qwen_provider.dart';

/// Доступные провайдеры LLM.
enum AiProviderKind { qwen, openai }

/// Конфигурация выбора активного провайдера.
///
/// Сейчас по умолчанию используется **Qwen**. Переключить можно флагом сборки:
/// `--dart-define=AI_PROVIDER=openai`.
class AiConfig {
  const AiConfig._();

  static const String _raw =
      String.fromEnvironment('AI_PROVIDER', defaultValue: 'qwen');

  /// Активный провайдер (по умолчанию Qwen).
  static AiProviderKind get active => switch (_raw.toLowerCase()) {
        'openai' => AiProviderKind.openai,
        _ => AiProviderKind.qwen,
      };

  /// Создаёт экземпляр активного провайдера.
  static AiProvider createProvider() => switch (active) {
        AiProviderKind.qwen => QwenProvider(),
        AiProviderKind.openai => OpenAiProvider(),
      };
}
