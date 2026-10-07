import 'package:bfit/core/palette.dart';
import 'package:bfit/core/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('daily progress is labelled accessibly and adapts to the goal', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: bfitTheme(false),
        home: const Scaffold(
          body: Center(child: ProgressRing(steps: 4000, goal: 8000)),
        ),
      ),
    );

    expect(find.text('4,000'), findsOneWidget);
    expect(find.text('of 8,000 steps'), findsOneWidget);
    expect(find.bySemanticsLabel('4000 of 8000 steps, 50 percent'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('primary action exposes its title and disabled state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: bfitTheme(false),
        home: Scaffold(
          body: Center(
            child: PrimaryAction(label: 'Save my goals', onPressed: null),
          ),
        ),
      ),
    );

    expect(find.text('Save my goals'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });
}
