import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_guardian/main.dart';

void main() {
  testWidgets(
    'Smart Guardian starts on Login Screen',
    (WidgetTester tester) async {
      await tester.pumpWidget(const SmartGuardianApp());

      expect(find.text('Smart Guardian'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    },
  );

  testWidgets(
    'Login navigates to Dashboard',
    (WidgetTester tester) async {
      await tester.pumpWidget(const SmartGuardianApp());

      await tester.enterText(
        find.byType(TextFormField).first,
        'test@example.com',
      );

      await tester.enterText(
        find.byType(TextFormField).last,
        'password123',
      );

      await tester.tap(find.text('Login'));

      await tester.pumpAndSettle();

      expect(find.text('Health Dashboard'), findsOneWidget);
      expect(find.text('Heart Rate'), findsOneWidget);
      expect(find.text('SpO₂'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
    },
  );
}