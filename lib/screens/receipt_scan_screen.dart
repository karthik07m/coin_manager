import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/receipt_scanner_service.dart';
import '../utilities/constants.dart';
import '../utilities/theme_helper.dart';

class ReceiptScanScreen extends StatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  State<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends State<ReceiptScanScreen> {
  final ReceiptScannerService _scannerService = ReceiptScannerService();
  ScanResult? _scanResult;
  bool _isLoading = false;
  String? _errorMessage;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  DateTime? _validatedDate;

  @override
  void dispose() {
    _scannerService.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _scanReceipt(bool fromCamera) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _scannerService.scanReceipt(fromCamera: fromCamera);
      if (result != null) {
        setState(() {
          _scanResult = result;
          _titleController.text = result.extractedTitle ?? '';
          _amountController.text =
              result.extractedAmount?.toStringAsFixed(2) ?? '';
          if (result.extractedDate != null) {
            _validatedDate = result.extractedDate;
            _dateController.text =
                DateFormat.yMMMd().format(result.extractedDate!);
          } else {
            _validatedDate = null;
            _dateController.clear();
          }
        });
      } else {
        setState(() {
          _errorMessage = 'No image selected';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error scanning receipt: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _confirmAndReturn() {
    final amount = double.tryParse(_amountController.text);
    final title = _titleController.text.trim();

    if (_scanResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan a receipt first')),
      );
      return;
    }

    Navigator.of(context).pop({
      'imagePath': _scanResult!.imagePath,
      'rawText': _scanResult!.rawText,
      'title': title.isNotEmpty ? title : null,
      'amount': amount,
      'date': _validatedDate,
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _validatedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _validatedDate = picked;
        _dateController.text = DateFormat.yMMMd().format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        title: Text(
          'Scan Receipt',
          style: AppTextStyles.h2,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview area with modern styling
            Container(
              height: 280,
              decoration: BoxDecoration(
                gradient: _scanResult == null
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.appSurface,
                          context.appSurfaceLight,
                        ],
                      )
                    : null,
                color: _scanResult != null ? context.appSurface : null,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                border: Border.all(
                  color: _scanResult != null
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : context.textSecondary.withValues(alpha: 0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Processing receipt...',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _scanResult != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusLarge - 2),
                          child: Image.file(
                            File(_scanResult!.imagePath),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.receipt_long,
                                  size: 64,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No receipt scanned yet',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Capture or select a receipt to extract data',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
            const SizedBox(height: AppDimensions.spacing20),

            // Capture buttons with modern design
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _scanReceipt(true),
                    icon: const Icon(Icons.camera_alt, size: 20),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _scanReceipt(false),
                    icon: const Icon(Icons.photo_library, size: 20),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: AppDimensions.spacing16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.negative.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(
                    color: AppColors.negative.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.negative,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.negative,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_scanResult != null) ...[
              const SizedBox(height: AppDimensions.spacing24),
              Row(
                children: [
                  Icon(
                    Icons.edit_note,
                    size: 20,
                    color: context.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'EXTRACTED INFORMATION',
                    style: AppTextStyles.caption.copyWith(
                      color: context.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing16),

              // Title field with modern styling
              Container(
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(
                    color: context.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                child: TextField(
                  controller: _titleController,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Store Name / Title',
                    labelStyle: AppTextStyles.bodyMedium.copyWith(
                      color: context.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    prefixIcon: Icon(
                      Icons.store,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Amount field
              Container(
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(
                    color: context.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                child: TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle: AppTextStyles.bodyMedium.copyWith(
                      color: context.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    prefixIcon: Icon(
                      Icons.attach_money,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Date field
              Container(
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(
                    color: context.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                child: TextField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: _selectDate,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Date',
                    labelStyle: AppTextStyles.bodyMedium.copyWith(
                      color: context.textSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    prefixIcon: Icon(
                      Icons.calendar_today,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacing20),

              // Raw text preview with modern styling
              Container(
                decoration: BoxDecoration(
                  color: context.appSurface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMedium),
                  border: Border.all(
                    color: context.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    'Raw OCR Text',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  leading: Icon(
                    Icons.text_snippet,
                    color: AppColors.primary,
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: context.appBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _scanResult!.rawText.isEmpty
                            ? 'No text extracted'
                            : _scanResult!.rawText,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontFamily: 'monospace',
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.spacing24),

              // Confirm button with modern styling
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _confirmAndReturn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Use This Receipt',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacing20),
            ],
          ],
        ),
      ),
    );
  }
}
