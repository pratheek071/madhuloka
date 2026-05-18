import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import '../../providers/restaurant_provider.dart';
import '../../models/table_model.dart';

class QrCodeView extends StatefulWidget {
  const QrCodeView({super.key});

  @override
  State<QrCodeView> createState() => _QrCodeViewState();
}

class _QrCodeViewState extends State<QrCodeView> {
  final TextEditingController _baseUrlController = TextEditingController(
    text: 'https://your-app.web.app',
  );

  String get baseUrl => _baseUrlController.text.trim();

  String _getOrderUrl(String tableId) {
    final url = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return '${url}?table=$tableId';
  }

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
    final provider = context.watch<RestaurantProvider>();
    final tables = provider.tables;

    return Column(
      children: [
        // Base URL Configuration
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.deepOrange.shade50,
          child: Row(
            children: [
              const Icon(Icons.link, color: Colors.deepOrange),
              const SizedBox(width: 12),
              const Text('Base URL: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: TextField(
                  controller: _baseUrlController,
                  decoration: const InputDecoration(
                    hintText: 'https://your-app.web.app',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _printMenuQr(),
                icon: const Icon(Icons.qr_code),
                label: const Text('Print Menu QR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _printAllQrCodes(tables),
                icon: const Icon(Icons.print_rounded),
                label: const Text('Print All QRs'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Grid of QR Cards
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              childAspectRatio: 0.8,
            ),
            itemCount: tables.length + 1,
            itemBuilder: (context, index) {
              if (index == tables.length) {
                return _AddTableCard(
                  onTap: () => _showTableDialog(context),
                );
              }

              final table = tables[index];
              final orderUrl = _getOrderUrl(table.id);

              return _QrCard(
                table: table,
                orderUrl: orderUrl,
                onPrint: () => _printSingleQr(table),
                onEdit: () => _showTableDialog(context, table: table),
                onDelete: () => provider.deleteTable(table.id),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showTableDialog(BuildContext context, {RestaurantTable? table}) {
    final nameController = TextEditingController(text: table?.name ?? '');
    final provider = context.read<RestaurantProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(table == null ? 'Add New Table' : 'Edit Table'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Table Name',
            hintText: 'e.g., Table 12',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                if (table == null) {
                  provider.addTable(nameController.text.trim());
                } else {
                  provider.updateTable(table.id, nameController.text.trim());
                }
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _printSingleQr(RestaurantTable table) async {
    final pdf = pw.Document();
    final url = _getOrderUrl(table.id);

    // Generate QR image bytes
    final qrImageBytes = await _generateQrImageBytes(url);
    final qrImage = pw.MemoryImage(qrImageBytes);

    final qrPageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      110 * PdfPageFormat.mm,
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
                pw.Text(table.name.toUpperCase(),
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text('Scan to Order', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'QR_${table.name}',
    );
  }

  Future<void> _printMenuQr() async {
    final pdf = pw.Document();
    final url = _getMenuUrl();

    final qrImageBytes = await _generateQrImageBytes(url);
    final qrImage = pw.MemoryImage(qrImageBytes);

    final qrPageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      110 * PdfPageFormat.mm,
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
    );
  }

  Future<void> _printSharedQr(RestaurantTable table) async {
    final pdf = pw.Document();
    final url = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final namedUrl = '${url}?table=${table.id}&mode=named';

    final qrImageBytes = await _generateQrImageBytes(namedUrl);
    final qrImage = pw.MemoryImage(qrImageBytes);

    final qrPageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      115 * PdfPageFormat.mm,
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
                  child: pw.Image(qrImage, width: 120, height: 120),
                ),
                pw.SizedBox(height: 6),
                pw.Text('SCAN TO ORDER - ${table.name.toUpperCase()}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                pw.SizedBox(height: 2),
                pw.Text('Enter your name to order', style: const pw.TextStyle(fontSize: 8)),
                pw.Text('Each person gets a separate bill', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'QR_Shared_${table.name}',
    );
  }

  Future<void> _printAllQrCodes(List<RestaurantTable> tables) async {
    if (tables.isEmpty) return;

    final pdf = pw.Document();
    final qrPageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      110 * PdfPageFormat.mm,
      marginAll: 4 * PdfPageFormat.mm,
    );

    for (final table in tables) {
      final url = _getOrderUrl(table.id);
      final qrImageBytes = await _generateQrImageBytes(url);
      final qrImage = pw.MemoryImage(qrImageBytes);

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
                  pw.Text(table.name.toUpperCase(),
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('Scan to Order', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'All_Table_QR_Codes',
    );
  }

  Future<Uint8List> _generateQrImageBytes(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
    );

    final imageSize = 300.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw white background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, imageSize, imageSize),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    qrPainter.paint(canvas, Size(imageSize, imageSize));
    final picture = recorder.endRecording();
    final image = await picture.toImage(imageSize.toInt(), imageSize.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

class _QrCard extends StatelessWidget {
  final RestaurantTable table;
  final String orderUrl;
  final VoidCallback onPrint;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QrCard({
    required this.table,
    required this.orderUrl,
    required this.onPrint,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Table Name & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32), // Spacer for centering title
                Expanded(
                  child: Text(
                    table.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Edit Table',
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Table?'),
                            content: Text('Are you sure you want to delete ${table.name}?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () {
                                  onDelete();
                                  Navigator.pop(context);
                                },
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Delete Table',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // QR Code
            Expanded(
              child: QrImageView(
                data: orderUrl,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.circle,
                  color: Color(0xFFE65100),
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: Color(0xFF212121),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // URL preview
            Text(
              orderUrl,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            // Print Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print QR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepOrange,
                  side: const BorderSide(color: Colors.deepOrange),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTableCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTableCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 2,
        color: Colors.grey.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.deepOrange.shade100, width: 2, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                size: 48,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add New Table',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Click to create more',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
