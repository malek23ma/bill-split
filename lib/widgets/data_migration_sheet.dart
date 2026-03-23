import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/data_migration_service.dart';

class DataMigrationSheet extends StatefulWidget {
  final int billCount;
  final int householdCount;
  final DataMigrationService migrationService;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const DataMigrationSheet({
    super.key,
    required this.billCount,
    required this.householdCount,
    required this.migrationService,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<DataMigrationSheet> createState() => _DataMigrationSheetState();
}

class _DataMigrationSheetState extends State<DataMigrationSheet> {
  bool _uploading = false;
  double _progress = 0.0;
  String? _error;

  Future<void> _startMigration() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await for (final progress
          in widget.migrationService.migrateLocalData()) {
        if (mounted) setState(() => _progress = progress);
      }
      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = 'Upload failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(AppScale.padding(24)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkDivider : AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: AppScale.size(20)),
          Icon(Icons.cloud_upload_rounded,
              size: AppScale.size(48), color: AppColors.primary),
          SizedBox(height: AppScale.size(16)),
          Text('Existing Data Found',
              style: TextStyle(
                  fontSize: AppScale.fontSize(20),
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary)),
          SizedBox(height: AppScale.size(8)),
          Text(
            'You have ${widget.billCount} bills across '
            '${widget.householdCount} households. '
            'Upload to your new account?',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: AppScale.fontSize(14),
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary),
          ),
          if (_error != null) ...[
            SizedBox(height: AppScale.size(12)),
            Text(_error!,
                style: TextStyle(
                    color: AppColors.negative,
                    fontSize: AppScale.fontSize(13))),
          ],
          if (_uploading) ...[
            SizedBox(height: AppScale.size(20)),
            LinearProgressIndicator(
                value: _progress, color: AppColors.primary),
            SizedBox(height: AppScale.size(8)),
            Text('${(_progress * 100).toInt()}%',
                style: TextStyle(
                    fontSize: AppScale.fontSize(13),
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary)),
          ],
          SizedBox(height: AppScale.size(24)),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _uploading ? null : _startMigration,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    EdgeInsets.symmetric(vertical: AppScale.padding(14)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
              child: Text(_uploading ? 'Uploading...' : 'Upload',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(height: AppScale.size(12)),
          TextButton(
            onPressed: _uploading ? null : widget.onSkip,
            child: Text('Start Fresh',
                style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary)),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
