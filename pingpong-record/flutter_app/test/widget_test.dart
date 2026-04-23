import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('shows the three planned feature tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const PinponRecordApp());

    expect(find.text('ピンポンの記録'), findsOneWidget);
    expect(find.text('履歴'), findsOneWidget);
    expect(find.text('分析'), findsOneWidget);
    expect(find.text('登録'), findsOneWidget);

    await tester.tap(find.text('登録'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
