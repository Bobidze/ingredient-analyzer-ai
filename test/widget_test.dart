import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sostav/screens/input_screen.dart';

void main() {
  testWidgets('Экран ввода отображает элементы управления', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: InputScreen()),
      ),
    );

    expect(find.text('Анализатор состава'), findsOneWidget);
    expect(find.text('Сделать фото'), findsOneWidget);
    expect(find.text('Из галереи'), findsOneWidget);
    expect(find.text('Анализировать'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Пустой ввод показывает подсказку и не переходит дальше',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: InputScreen()),
      ),
    );

    await tester.tap(find.text('Анализировать'));
    await tester.pump();

    expect(
      find.text('Добавьте фото состава или введите его текстом.'),
      findsOneWidget,
    );
  });
}
