import 'ai_provider.dart';

/// Провайдер Alibaba Bailian (Qwen) через OpenAI-совместимый эндпоинт.
///
/// Использует vision-модель `qwen3-vl-plus`. Ключ и настройки читаются
/// только из окружения сборки (`--dart-define`) — ничего не хардкодится.
class QwenProvider extends OpenAiCompatibleProvider {
  QwenProvider({super.client});

  @override
  String get name => 'Qwen (Bailian)';

  @override
  String get apiKeyEnvName => 'DASHSCOPE_API_KEY';

  @override
  String get apiKey => const String.fromEnvironment('DASHSCOPE_API_KEY');

  /// Международный (Singapore) OpenAI-совместимый эндпоинт Bailian.
  /// Для региона Пекин: https://dashscope.aliyuncs.com/compatible-mode/v1
  @override
  String get baseUrl => const String.fromEnvironment(
        'QWEN_BASE_URL',
        defaultValue: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
      );

  /// Актуальная мультимодальная модель Bailian с поддержкой изображений.
  @override
  String get model => const String.fromEnvironment(
        'QWEN_MODEL',
        defaultValue: 'qwen3-vl-plus',
      );

  /// Для VL-моделей json_object в доках Bailian явно не гарантирован,
  /// поэтому по умолчанию полагаемся на системный промпт + валидацию.
  /// Включается флагом сборки при необходимости.
  @override
  bool get supportsJsonMode => const bool.fromEnvironment(
        'QWEN_JSON_MODE',
        defaultValue: false,
      );
}
