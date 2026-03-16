import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/cloud_receipt_scanner.dart';
import '../services/receipt_scanner.dart';
import '../services/receipt_parser.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final _scanner = ReceiptScanner();
  final _parser = ReceiptParser();
  final _picker = ImagePicker();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _captureAndProcess(ImageSource source) async {
    final billType = ModalRoute.of(context)!.settings.arguments as String;

    final image = await _picker.pickImage(
      source: source,
      maxWidth: 2560,
      maxHeight: 2560,
      imageQuality: 100,
    );

    if (image == null) return;

    setState(() => _isProcessing = true);

    try {
      ParsedReceipt parsed;
      final apiKey = context.read<SettingsProvider>().apiKey;

      if (apiKey.isNotEmpty) {
        final cloudScanner = CloudReceiptScanner(apiKey: apiKey);
        parsed = await cloudScanner.scanAndParse(image.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI scan: ${parsed.items.length} items found'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        final rawText = await _scanner.scanImage(image.path);
        parsed = _parser.parse(rawText);
      }

      if (!mounted) return;

      final route = billType == 'full' ? '/item-review' : '/quick-review';
      Navigator.pushReplacementNamed(
        context,
        route,
        arguments: {
          'parsed': parsed,
          'photoPath': image.path,
          'billType': billType,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasApiKey = context.watch<SettingsProvider>().apiKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(hasApiKey
                      ? 'Reading receipt with AI...'
                      : 'Reading receipt...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.document_scanner,
                      size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 24),
                  Text(
                    'Take a photo of your receipt',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (!hasApiKey) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Set up AI scanning in Settings for better results',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () =>
                          _captureAndProcess(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _captureAndProcess(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Pick from Gallery',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
