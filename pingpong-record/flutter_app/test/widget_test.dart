import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/src/features/register/register_match_screen.dart';

void main() {
  testWidgets('shows the three planned feature tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PinponRecordApp());

    expect(find.text('ピンポンの記録'), findsOneWidget);
    expect(find.text('履歴'), findsOneWidget);
    expect(find.text('分析'), findsOneWidget);
    expect(find.text('登録'), findsOneWidget);

    await tester.tap(find.text('登録'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  test('normalizes a leading zero in score input', () {
    final formatter = ScoreRangeInputFormatter();

    final result = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      ),
      const TextEditingValue(
        text: '06',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );

    expect(result.text, '6');
    expect(result.selection.baseOffset, 1);
  });

  test('does not autofill the opponent score when 0 is entered', () {
    expect(scoreAutofillValue(rawValue: '6', targetValue: '8'), '11');
    expect(scoreAutofillValue(rawValue: '0', targetValue: '8'), isNull);
  });
}
