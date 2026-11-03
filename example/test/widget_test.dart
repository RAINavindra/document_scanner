import 'package:document_scanner_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Renders home page with start scanning button', (tester) async {
    await tester.pumpWidget(const DocumentScannerExampleApp());

    expect(find.text('Document Scanner'), findsOneWidget);
    expect(find.text('Start Scanning'), findsOneWidget);
  });
}
