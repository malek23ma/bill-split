import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/cloud_receipt_scanner.dart';
import '../services/receipt_scanner.dart';
import '../services/receipt_parser.dart';
import '../constants.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  final _scanner = ReceiptScanner();
  final _parser = ReceiptParser();
  final _picker = ImagePicker();
  bool _isProcessing = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _captureAndProcess(ImageSource source) async {
    final billType = ModalRoute.of(context)!.settings.arguments as String;
    final apiKey = context.read<SettingsProvider>().apiKey;

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

      if (apiKey.isNotEmpty) {
        final cloudScanner = CloudReceiptScanner(apiKey: apiKey);
        parsed = await cloudScanner.scanAndParse(image.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI scan: ${parsed.items.length} items found'),
              backgroundColor: AppColors.positive,
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
          backgroundColor: AppColors.negative,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasApiKey = context.watch<SettingsProvider>().apiKey.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Scan Receipt',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: AppScale.fontSize(20),
          ),
        ),
        iconTheme: IconThemeData(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
      ),
      body: _isProcessing
          ? _buildProcessingState(hasApiKey, isDark)
          : _buildIdleState(hasApiKey, isDark),
    );
  }

  Widget _buildProcessingState(bool hasApiKey, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.15);
              final opacity = 0.5 + (_pulseController.value * 0.5);
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: AppScale.size(88),
                    height: AppScale.size(88),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.primary.withAlpha(40) : AppColors.primarySurface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.document_scanner_rounded,
                      size: AppScale.size(40),
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: AppScale.size(24)),
          SizedBox(
            width: AppScale.size(28),
            height: AppScale.size(28),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasApiKey ? 'Reading receipt with AI...' : 'Reading receipt...',
            style: TextStyle(
              fontSize: AppScale.fontSize(17),
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This may take a moment',
            style: TextStyle(
              fontSize: AppScale.fontSize(14),
              color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleState(bool hasApiKey, bool isDark) {
    return Padding(
      padding: EdgeInsets.all(AppScale.padding(24)),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Dashed border scan area
          SizedBox(
            width: AppScale.size(200),
            height: AppScale.size(200),
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: isDark ? AppColors.primary : AppColors.primaryLight,
                radius: AppRadius.xl,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: AppScale.size(64),
                      height: AppScale.size(64),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.primary.withAlpha(40) : AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(
                        Icons.document_scanner_rounded,
                        size: AppScale.size(32),
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Scan Receipt',
                      style: TextStyle(
                        fontSize: AppScale.fontSize(14),
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'Take a photo of your receipt',
            style: TextStyle(
              fontSize: AppScale.fontSize(22),
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),
          Text(
            'Position the receipt clearly in the frame',
            style: TextStyle(
              fontSize: AppScale.fontSize(14),
              color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(flex: 2),

          // Camera button — filled, full width, primary
          SizedBox(
            width: double.infinity,
            height: AppScale.size(56),
            child: FilledButton.icon(
              onPressed: () => _captureAndProcess(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(
                'Take Photo',
                style: TextStyle(fontSize: AppScale.fontSize(16), fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Gallery button — outlined, full width, divider border
          SizedBox(
            width: double.infinity,
            height: AppScale.size(56),
            child: OutlinedButton.icon(
              onPressed: () => _captureAndProcess(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded),
              label: Text(
                'Pick from Gallery',
                style: TextStyle(fontSize: AppScale.fontSize(16), fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                side: BorderSide(
                    color: isDark ? AppColors.darkDivider : AppColors.divider, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
            ),
          ),

          SizedBox(height: AppScale.size(16)),

          // AI hint card
          if (!hasApiKey)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppScale.padding(14)),
              decoration: BoxDecoration(
                color: isDark ? AppColors.accent.withAlpha(25) : AppColors.accentSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: AppScale.size(20),
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Set up AI scanning in Settings for better results',
                      style: TextStyle(
                        fontSize: AppScale.fontSize(13),
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    const dashWidth = 8.0;
    const dashSpace = 5.0;

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0, metric.length).toDouble();
        final extractPath = metric.extractPath(distance, end);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}
