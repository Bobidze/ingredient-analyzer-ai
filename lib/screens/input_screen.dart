import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/analysis_provider.dart';
import 'result_screen.dart';

/// Экран ввода: фото/галерея + ручной ввод состава + «Анализировать».
class InputScreen extends ConsumerStatefulWidget {
  const InputScreen({super.key});

  @override
  ConsumerState<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends ConsumerState<InputScreen> {
  final _textController = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _imageBytes;
  String _imageMime = 'image/jpeg';
  bool _picking = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      // Сжимаем на устройстве до отправки: меньше картинка — быстрее и
      // загрузка, и распознавание моделью. 1280px хватает, чтобы читался
      // мелкий текст состава.
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageMime = _mimeFor(file);
      });
    } catch (_) {
      if (!mounted) return;
      _snack('Не удалось получить изображение.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  String _mimeFor(XFile file) {
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic')) return 'image/heic';
    return file.mimeType ?? 'image/jpeg';
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _analyze() {
    final text = _textController.text.trim();
    final hasText = text.isNotEmpty;
    final hasImage = _imageBytes != null;

    // Валидация до отправки запроса.
    if (!hasText && !hasImage) {
      _snack('Добавьте фото состава или введите его текстом.');
      return;
    }
    if (!ref.read(aiProviderProvider).isConfigured) {
      _snack('Не задан API-ключ провайдера. Запустите с --dart-define.');
      return;
    }

    ref.read(analysisControllerProvider.notifier).analyze(
          text: hasText ? text : null,
          imageBytes: _imageBytes,
          mimeType: _imageMime,
        );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ResultScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Состав'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Анализатор состава',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Сфотографируйте этикетку или введите состав вручную — '
              'разберём каждый ингредиент.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Превью выбранного изображения.
            if (_imageBytes != null) ...[
              _ImagePreview(
                bytes: _imageBytes!,
                onRemove: () => setState(() => _imageBytes = null),
              ),
              const SizedBox(height: 16),
            ],

            // Две кнопки источника изображения.
            Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_camera_outlined,
                    label: 'Сделать фото',
                    onTap: _picking ? null : () => _pick(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Из галереи',
                    onTap: _picking ? null : () => _pick(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(child: Divider(color: theme.dividerColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'или введите текстом',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: theme.dividerColor)),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _textController,
              minLines: 4,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText:
                    'Например: вода, сахар, лимонная кислота, бензоат натрия…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            FilledButton(
              onPressed: _analyze,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Анализировать',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Image.memory(
            bytes,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'Убрать фото',
                onPressed: onRemove,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
