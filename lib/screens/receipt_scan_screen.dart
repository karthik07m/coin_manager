import 'dart:io';
import 'package:flutter/material.dart';
import '../services/receipt_scanner_service.dart';

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

  @override
  void dispose() {
    _scannerService.dispose();
    _titleController.dispose();
    _amountController.dispose();
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image preview area
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _scanResult != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_scanResult!.imagePath),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long,
                                size: 64,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Capture or select a receipt',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
            ),
            const SizedBox(height: 16),

            // Capture buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _scanReceipt(true),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _scanReceipt(false),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[700]),
                ),
              ),
            ],

            if (_scanResult != null) ...[
              const SizedBox(height: 24),
              const Text(
                'Extracted Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Title field
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title / Store Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.store),
                ),
              ),
              const SizedBox(height: 12),

              // Amount field
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 16),

              // Raw text preview
              ExpansionTile(
                title: const Text('Raw OCR Text'),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _scanResult!.rawText.isEmpty
                          ? 'No text extracted'
                          : _scanResult!.rawText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Confirm button
              ElevatedButton(
                onPressed: _confirmAndReturn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Use This Receipt',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
