import 'package:document_scanner/document_scanner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('DocumentScannerController instantiates with default settings', (tester) async {
    final controller = DocumentScannerController();
    expect(controller.state, equals(ScannerState.initializing));
    expect(controller.enableAutoCapture, isTrue);
    expect(controller.defaultFilter, equals(ScanFilter.enhance));
  });
}
