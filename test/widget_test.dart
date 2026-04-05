import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_learn/main.dart';

void main() {
  testWidgets('Phase 1: アプリが ProviderScope 付きで起動する', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Phase 1 完了 - Firebase セットアップ待ち'), findsOneWidget);
  });
}
