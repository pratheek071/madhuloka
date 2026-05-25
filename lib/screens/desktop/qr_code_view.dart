import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

class QrCodeView extends StatefulWidget {
  const QrCodeView({super.key});

  @override
  State<QrCodeView> createState() => _QrCodeViewState();
}

class _QrCodeViewState extends State<QrCodeView> {
  final TextEditingController _baseUrlController = TextEditingController(
    text: 'https://madhuloka-fd294.web.app',
  );

  String get baseUrl => _baseUrlController.text.trim();

  String _getMenuUrl() {
    final url = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return '${url}?mode=view';
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menuUrl = _getMenuUrl();

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('MADHULOKA DINING', 
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.deepOrange, letterSpacing: 1.1)),
                  const SizedBox(height: 6),
                  const Text('Digital Menu QR Code', 
                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 28),
                  
                  // Premium QR Image Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: QrImageView(
                      data: menuUrl,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.circle,
                        color: Color(0xFFE65100),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.circle,
                        color: Color(0xFF212121),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Base URL input
                  TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Menu Base URL',
                      hintText: 'https://madhuloka-fd294.web.app',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link, color: Colors.deepOrange),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  
                  // Scan Link Preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_scanner, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            menuUrl,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Premium Print Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () => _printMenuQr(),
                      icon: const Icon(Icons.print_rounded, size: 22),
                      label: const Text('Print Menu QR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _printMenuQr() async {
    final pdf = pw.Document();
    final url = _getMenuUrl();

    final qrImageBytes = await _generateQrImageBytes(url);
    final qrImage = pw.MemoryImage(qrImageBytes);

    final qrPageFormat = PdfPageFormat(
      79 * PdfPageFormat.mm,
      79 * PdfPageFormat.mm,
      marginAll: 4 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: qrPageFormat,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('MADHULOKA DINING',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1.5),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Image(qrImage, width: 130, height: 130),
                ),
                pw.SizedBox(height: 6),
                pw.Text('SCAN TO VIEW MENU',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                pw.SizedBox(height: 2),
                pw.Text('View Only Mode', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'QR_Menu_Only',
      format: qrPageFormat,
    );
  }

  Future<Uint8List> _generateQrImageBytes(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      color: const ui.Color(0xFF000000),
      emptyColor: const ui.Color(0xFFFFFFFF),
    );

    const imageSize = 300.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Draw white background
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, imageSize, imageSize),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    qrPainter.paint(canvas, const ui.Size(imageSize, imageSize));
    final picture = recorder.endRecording();
    final image = await picture.toImage(imageSize.toInt(), imageSize.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
