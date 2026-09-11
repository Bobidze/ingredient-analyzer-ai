import 'ai_provider.dart';

/// Провайдер OpenAI. Оставлен как альтернатива — переключается в конфиге.
class OpenAiProvider extends OpenAiCompatibleProvider {
  OpenAiProvider({super.client});

  @override
  String get name => 'OpenAI';

  @override
  String get apiKeyEnvName => 'OPENAI_API_KEY';

  @override
  String get apiKey => const String.fromEnvironment('OPENAI_API_KEY');

  @override
  String get baseUrl => const String.fromEnvironment(
        'OPENAI_BASE_URL',
        defaultValue: 'https://api.openai.com/v1',
      );

  @override
  String get model => const String.fromEnvironment(
        'OPENAI_MODEL',
        defaultValue: 'gpt-4o-mini',
      );

  /// OpenAI поддерживает строгий JSON-режим.
  @override
  bool get supportsJsonMode => true;
}
