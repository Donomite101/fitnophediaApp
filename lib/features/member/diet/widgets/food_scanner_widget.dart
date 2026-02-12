import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:iconsax/iconsax.dart';

class FoodScannerWidget extends StatefulWidget {
  final Function(String) onScan;
  final String title;

  const FoodScannerWidget({
    super.key, 
    required this.onScan,
    this.title = "SCAN BARCODE",
  });

  @override
  State<FoodScannerWidget> createState() => _FoodScannerWidgetState();
}

class _FoodScannerWidgetState extends State<FoodScannerWidget> {
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_isScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  setState(() => _isScanned = true);
                  widget.onScan(code);
                  Navigator.pop(context);
                }
              }
            },
          ),
          
          // Overlay UI
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      ),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 48), // Spacer
                    ],
                  ),
                ),
                const Spacer(),
                // Scanner Frame
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF00C853), width: 2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Text(
                    "Center the barcode within the frame",
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Outfit',
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
