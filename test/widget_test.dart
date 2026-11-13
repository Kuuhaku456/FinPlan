import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FinPlan widget test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('FinPlan'))),
      ),
    );

    expect(find.text('FinPlan'), findsOneWidget);
  });
}
