import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/analysis_result.dart';

/// Базовое исключение слоя AI. У каждого подтипа есть [message] —
/// готовый к показу пользователю русский текст.
sealed class AiException implements Exception {
  const AiException(this.message);
  final String message;

  @override
  String toString() => 'AiException: $message';
}

/// Нет ключа API (забыли передать --dart-define).
class MissingApiKeyException extends AiException {
  const MissingApiKeyException(super.message);
}

/// Проблемы с сетью (нет интернета, DNS и т.п.).
class NetworkException extends AiException {
  const NetworkException()
      : super('Нет подключения к интернету. Проверьте сеть и повторите.');
}

/// Запрос не уложился в таймаут.
class RequestTimeoutException extends AiException {
  const RequestTimeoutException()
      : super('Превышено время ожидания ответа. Попробуйте ещё раз.');
}

/// 429 — превышен лимит запросов.
class RateLimitException extends AiException {
  const RateLimitException()
      : super('Превышен лимит запросов. Подождите немного и повторите.');
}

/// Модель вернула не то, что ожидалось (битый или неполный JSON).
class InvalidResponseException extends AiException {
  const InvalidResponseException()
      : super('Не удалось разобрать ответ. Попробуйте ещё раз.');
}

/// Прочие ошибки API (4xx/5xx, кроме 429).
class ApiException extends AiException {
  const ApiException(super.message);
}

/// Абстракция над LLM-провайдером.
///
/// Единственная задача — разобрать состав в [AnalysisResult].
/// Реализации: [QwenProvider], [OpenAiProvider]. Активный выбирается в конфиге.
abstract class AiProvider {
  /// Человекочитаемое имя (для сообщений/диагностики).
  String get name;

  /// Готов ли провайдер к работе (есть ключ API).
  bool get isConfigured;

  /// Анализирует состав. Нужно передать хотя бы одно из [text] / [imageBytes].
  Future<AnalysisResult> analyzeIngredients({
    String? text,
    Uint8List? imageBytes,
    String mimeType = 'image/jpeg',
  });

  /// Освобождение ресурсов (http-клиент и т.п.).
  void dispose() {}
}

/// Общая реализация для всех OpenAI-совместимых провайдеров
/// (Qwen/Bailian, OpenAI). Подклассы задают только эндпоинт, ключ и модель.
abstract class OpenAiCompatibleProvider extends AiProvider {
  OpenAiCompatibleProvider({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  // --- то, что определяют конкретные провайдеры ---

  /// Базовый URL до `/v1` (без завершающего слэша).
  String get baseUrl;

  /// Ключ API.
  String get apiKey;

  /// Идентификатор модели с поддержкой изображений.
  String get model;

  /// Поддерживает ли провайдер `response_format: {type: json_object}`.
  /// Если да — просим строгий JSON на уровне API; если нет — полагаемся
  /// на инструкцию в системном промпте и валидацию при парсинге.
  bool get supportsJsonMode;

  /// Имя переменной окружения с ключом (для понятного сообщения об ошибке).
  String get apiKeyEnvName;

  /// Vision-модель на фото может отвечать десятки секунд, поэтому таймаут
  /// щедрый и настраивается флагом сборки --dart-define=AI_TIMEOUT_SECONDS=...
  static const Duration _timeout = Duration(
    seconds: int.fromEnvironment('AI_TIMEOUT_SECONDS', defaultValue: 60),
  );

  @override
  bool get isConfigured => apiKey.isNotEmpty;

  @override
  Future<AnalysisResult> analyzeIngredients({
    String? text,
    Uint8List? imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    if (!isConfigured) {
      throw MissingApiKeyException(
        'API-ключ не найден. Запустите приложение с '
        '--dart-define=$apiKeyEnvName=ваш_ключ',
      );
    }

    final hasText = text != null && text.trim().isNotEmpty;
    final hasImage = imageBytes != null && imageBytes.isNotEmpty;
    if (!hasText && !hasImage) {
      throw const ApiException('Нет данных для анализа.');
    }

    // Мультимодальный контент пользователя (текст и/или картинка).
    final userContent = <Map<String, dynamic>>[];
    if (hasText) {
      userContent.add({
        'type': 'text',
        'text': 'Состав от пользователя:\n${text.trim()}',
      });
    } else {
      userContent.add({
        'type': 'text',
        'text': 'Проанализируй состав продукта на фотографии этикетки.',
      });
    }
    if (hasImage) {
      final dataUri = 'data:$mimeType;base64,${base64Encode(imageBytes)}';
      userContent.add({
        'type': 'image_url',
        'image_url': {'url': dataUri},
      });
    }

    final requestBody = <String, dynamic>{
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userContent},
      ],
      'temperature': 0.2,
    };
    // Ветка «провайдер умеет json_object».
    if (supportsJsonMode) {
      requestBody['response_format'] = {'type': 'json_object'};
    }

    final uri = Uri.parse('$baseUrl/chat/completions');

    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const RequestTimeoutException();
    } on SocketException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }

    if (response.statusCode == 429) {
      throw const RateLimitException();
    }
    if (response.statusCode != 200) {
      throw ApiException(
        'Ошибка сервиса (${response.statusCode}). Попробуйте позже.',
      );
    }

    return _parseResponse(response.body);
  }

  /// Достаёт контент ответа (OpenAI-формат) и превращает его в [AnalysisResult].
  AnalysisResult _parseResponse(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody) as Map<String, dynamic>;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw const InvalidResponseException();
      }
      final message = choices.first['message'];
      final content = message is Map ? message['content'] : null;
      if (content is! String || content.trim().isEmpty) {
        throw const InvalidResponseException();
      }

      // Ветка «валидируем сами»: контент может прийти обёрнутым в ```json```
      // или с текстом вокруг — аккуратно вытаскиваем JSON-объект.
      final parsed = extractJsonObject(content);
      return AnalysisResult.fromJson(parsed);
    } on AiException {
      rethrow;
    } on FormatException {
      throw const InvalidResponseException();
    } catch (_) {
      throw const InvalidResponseException();
    }
  }

  @override
  void dispose() => _client.close();
}

/// Инструкция для модели. Требуем строго JSON и русский язык.
/// Схема продублирована здесь, чтобы работать и без `response_format`.
const String systemPrompt = '''
Ты — эксперт по пищевому и косметическому составу. Проанализируй состав
продукта, переданный текстом и/или на фотографии этикетки.

Для каждого ингредиента определи: название, категорию (консервант, краситель,
эмульгатор, витамин, подсластитель, антиоксидант и т.п.), для чего он нужен,
и уровень внимания:
- "safe" — безопасен в обычных количествах;
- "moderate" — есть нюансы (аллергия, ограничения, спорные данные);
- "avoid" — по возможности стоит избегать.

Также дай короткую общую оценку продукта и целочисленный балл от 1 до 10.
Если состав распознать невозможно — верни пустой список ingredients и поясни
это в product_summary.

Ответ верни СТРОГО в виде одного объекта JSON (json), без пояснений и без
markdown-разметки, точно по этой схеме:
{
  "product_summary": "строка на русском",
  "overall_score": целое_число_от_1_до_10,
  "ingredients": [
    {
      "name": "строка",
      "category": "строка",
      "purpose": "строка",
      "concern_level": "safe | moderate | avoid",
      "note": "строка"
    }
  ]
}
Все текстовые значения — на русском языке.''';

/// Извлекает JSON-объект из ответа модели, устойчиво к обёрткам:
/// markdown-фенсы, текст до/после объекта. Бросает [FormatException],
/// если валидный объект найти не удалось.
Map<String, dynamic> extractJsonObject(String raw) {
  var text = raw.trim();

  // Снимаем markdown-фенсы ```json ... ``` при их наличии.
  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3).trim();
    }
  }

  // Быстрый путь — весь ответ и есть JSON.
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    // пробуем вырезать объект по фигурным скобкам
  }

  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end > start) {
    final decoded = jsonDecode(text.substring(start, end + 1));
    if (decoded is Map<String, dynamic>) return decoded;
  }

  throw const FormatException('JSON-объект не найден в ответе');
}
