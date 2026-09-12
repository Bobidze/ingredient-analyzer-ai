# Sostav — food ingredient analyzer

**English** · [Русский](README.ru.md)

A Flutter app that breaks down a product's ingredient list from a photo of the
label or from typed text. The input is sent to an **LLM provider** (currently
**Qwen via Alibaba Bailian**, over an OpenAI-compatible API), which returns
strictly structured JSON: an overall product score and a list of ingredients
with category, purpose and concern level. Ingredients are rendered as cards with
color coding (🟢 safe · 🟡 some caveats · 🔴 better avoided).

<p align="center">
  <img src="screenshots/demo.gif" alt="Sostav app demo" width="320">
</p>

## Screenshots

| Input | Loading | Result |
|-------|---------|--------|
| ![Input screen](screenshots/screenshot_input.png) | ![Loading](screenshots/screenshot_loading.png) | ![Result](screenshots/screenshot_result.png) |

> Screenshots live in `screenshots/` as `screenshot_input.png`,
> `screenshot_loading.png` and `screenshot_result.png`.

## Features

- 📷 Label photo from camera or gallery, plus manual text input
- 🤖 Analysis through a multimodal model (Qwen-VL) with **structured JSON** output
- 🔌 Provider abstraction: switching between Qwen and OpenAI is one flag
- 🎨 Material 3, light and dark themes, large type, soft shadows
- 🧩 Ingredient cards with a colored concern-level stripe
- 🛡️ Full error handling: offline, timeout, rate limit (429), malformed JSON, empty input

## Running

You need an Alibaba Bailian / DashScope API key
(get one at <https://bailian.console.alibabacloud.com/>).
The key is **never stored in the code** — it is passed at launch via `--dart-define`:

```bash
flutter pub get

# run with the default provider (Qwen)
flutter run --dart-define=DASHSCOPE_API_KEY=YOUR_KEY

# release build (Android)
flutter build apk --dart-define=DASHSCOPE_API_KEY=YOUR_KEY
```

All configurable build parameters:

| dart-define | Default | Purpose |
|-------------|---------|---------|
| `AI_PROVIDER` | `qwen` | Active provider: `qwen` or `openai` |
| `DASHSCOPE_API_KEY` | — | Bailian key (for Qwen) |
| `QWEN_MODEL` | `qwen3-vl-plus` | Qwen vision model |
| `QWEN_BASE_URL` | `…dashscope-intl…/compatible-mode/v1` | Endpoint (Beijing: drop `-intl`) |
| `QWEN_JSON_MODE` | `false` | Whether to send `response_format: json_object` |
| `AI_TIMEOUT_SECONDS` | `60` | Model request timeout |
| `OPENAI_API_KEY` | — | OpenAI key (when `AI_PROVIDER=openai`) |
| `OPENAI_MODEL` | `gpt-4o-mini` | OpenAI model |

Switching to OpenAI:

```bash
flutter run --dart-define=AI_PROVIDER=openai --dart-define=OPENAI_API_KEY=YOUR_KEY
```

> Tip: to avoid retyping the key, use `--dart-define-from-file=env.json`
> (do not commit that file — it is already in `.gitignore`).

## Architecture

Classic layer separation, state handled by **Riverpod**.

```
lib/
├── main.dart                       # ProviderScope + Material 3 themes (light/dark)
├── config/
│   └── ai_config.dart              # picks the active provider (Qwen today)
├── models/
│   ├── ingredient.dart             # Ingredient + ConcernLevel enum (color/icon/label)
│   └── analysis_result.dart        # AnalysisResult + defensive fromJson
├── services/
│   ├── ai_provider.dart            # abstract AiProvider + OpenAI-compatible base + errors/schema
│   ├── qwen_provider.dart          # QwenProvider (Bailian, qwen3-vl-plus)
│   └── openai_provider.dart        # OpenAiProvider (alternative)
├── providers/
│   └── analysis_provider.dart      # AnalysisController → AsyncValue<AnalysisResult?>
├── screens/
│   ├── input_screen.dart           # input: camera/gallery/text + validation
│   └── result_screen.dart          # loading / data / error via state.when()
└── widgets/
    ├── ingredient_card.dart        # card with a colored stripe on the left
    ├── loading_view.dart
    └── error_view.dart
```

**Data flow.** `InputScreen` validates the input and calls
`AnalysisController.analyze()`. The controller emits `AsyncLoading`, calls the
active `AiProvider.analyzeIngredients()` through `AsyncValue.guard`, and stores
the result in `AsyncData` or the failure in `AsyncError`. `ResultScreen` watches
that state and renders the matching view via `state.when(...)`.

### Provider abstraction

```dart
abstract class AiProvider {
  String get name;
  bool get isConfigured;
  Future<AnalysisResult> analyzeIngredients({String? text, Uint8List? imageBytes, String mimeType});
}
```

Because both Bailian (Qwen) and OpenAI speak the same OpenAI-compatible
`/chat/completions` format, the shared HTTP logic lives in the base
`OpenAiCompatibleProvider`, while `QwenProvider` / `OpenAiProvider` only supply
the endpoint, key, model and JSON-mode flag. The active provider is selected in
`AiConfig` (`--dart-define=AI_PROVIDER=…`), defaulting to **Qwen**.

### State management (Riverpod)

The three UI states are three branches of a single `AsyncValue`:

- `AsyncData(null)` — idle (start screen);
- `AsyncLoading` — request in flight → `LoadingView`;
- `AsyncData(result)` — done → ingredient cards;
- `AsyncError(e)` — failure → `ErrorView` (`e` holds a typed `AiException`).

The controller remembers the last request, so the "Retry" button works without
going back to the input screen.

## How the response schema is enforced

The key part is making the model return **strict JSON** rather than free text.
The expected schema:

```jsonc
{
  "product_summary": "string",
  "overall_score": 7,               // integer 1..10
  "ingredients": [
    {
      "name": "Sodium benzoate",
      "category": "preservative",
      "purpose": "…",
      "concern_level": "moderate",  // "safe" | "moderate" | "avoid"
      "note": "…"
    }
  ]
}
```

A two-tier approach is used:

1. **If the provider supports `response_format: {type: "json_object"}`**
   (OpenAI does; for Qwen-VL it is enabled by the `QWEN_JSON_MODE` flag), it is
   sent with the request and the API guarantees a valid JSON object.
2. **Otherwise** the format is described in the system prompt (full schema plus
   a "return strict JSON, no markdown" instruction), and the reply is
   **validated while parsing**: `extractJsonObject()` strips markdown ```` ```json ````
   fences, slices the object out by its braces and decodes it.

The JSON then goes through the **defensive** `AnalysisResult.fromJson`: wrong
types, missing fields and unknown `concern_level` values never crash the app
(`overall_score` is clamped to 1–10, an unknown level falls back to `moderate`).

The request is multimodal: text and/or image (base64 `data:` URI in `image_url`)
are sent in a single `role: user` message. The model replies in Russian.

## Error handling

Every failure is a typed `AiException` subclass carrying a ready-to-show
message:

| Situation | Class | UI behavior |
|-----------|-------|-------------|
| Offline | `NetworkException` | message + "Retry" |
| Timeout (60 s) | `RequestTimeoutException` | dedicated message |
| Rate limit | `RateLimitException` (429) | "wait and try again" |
| Malformed JSON | `InvalidResponseException` | error shown, no crash |
| Missing key | `MissingApiKeyException` | hint about `--dart-define` |
| Empty input | — | validated before the request (SnackBar) |

## Stack

- Flutter 3.41 / Dart 3.11
- [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) — state management
- [http](https://pub.dev/packages/http) — calls to the OpenAI-compatible API
- [image_picker](https://pub.dev/packages/image_picker) — camera and gallery
- No backend: the app talks to the provider API directly

## Tests

```bash
flutter test
```

Covers rendering of the input screen and empty-input validation.

## Security

The API key is read only through `String.fromEnvironment` and is never
hardcoded. Do not commit keys or `--dart-define-from-file` files.
