import 'package:document_scanner/document_scanner.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DocumentScannerExampleApp());
}

class DocumentScannerExampleApp extends StatelessWidget {
  const DocumentScannerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Scanner Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<ScannedDocument> _scannedDocs = [];

  void _openScanner() async {
    final controller = DocumentScannerController(
      enableAutoCapture: true,
      defaultFilter: ScanFilter.enhance,
      sensitivity: DetectionSensitivity.lenient
    );

    final ScannedDocument? result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScannerScreen(controller: controller),
      ),
    );

    if (result != null) {
      setState(() {
        _scannedDocs.insert(0, result);
      });

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResultScreen(document: result),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Scanner'),
        centerTitle: true,
      ),
      body: _scannedDocs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.document_scanner,
                        size: 50,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Scans Yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Capture documents from the live camera stream with automatic edge detection and perspective correction.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _openScanner,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Start Scanning'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _scannedDocs.length,
              itemBuilder: (context, index) {
                final doc = _scannedDocs[index];
                final sizeKb = (doc.bytes.lengthInBytes / 1024).toStringAsFixed(1);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ResultScreen(document: doc),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              doc.bytes,
                              width: 70,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Document #${_scannedDocs.length - index}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Resolution: ${doc.width} x ${doc.height}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  'Size: $sizeKb KB',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: _scannedDocs.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _openScanner,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Document'),
            )
          : null,
    );
  }
}

class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key, required this.controller});

  final DocumentScannerController controller;

  @override
  Widget build(BuildContext context) {
    return DocumentScannerCamera(
      controller: controller,
      appBarTitle: 'Scan Document',
      openCropScreenOnCapture: true,
      onScanned: (document) {
        Navigator.of(context).pop(document);
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      },
    );
  }
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.document});

  final ScannedDocument document;

  @override
  Widget build(BuildContext context) {
    final sizeKb = (document.bytes.lengthInBytes / 1024).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scanned Document'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Document Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 24),
                      Text('Dimensions: ${document.width} x ${document.height} px'),
                      const SizedBox(height: 8),
                      Text('File Size: $sizeKb KB'),
                      const SizedBox(height: 8),
                      Text('Format: PNG (Perspective Warped)'),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            document.bytes,
            fit: BoxFit.contain,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          color: Colors.black,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check),
            label: const Text('Done'),
          ),
        ),
      ),
    );
  }
}
