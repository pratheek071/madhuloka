import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/order_model.dart';
import '../../models/order_item_model.dart';
import 'package:intl/intl.dart';

class BillingService {
  static Future<void> printInvoice(OrderModel order, {BuildContext? context, String? title, List<OrderItem>? customItems}) async {
    final pdf = pw.Document();
    final items = customItems ?? order.items;

    final double taxableTotal = items.where((item) {
          final type = item.itemType.toLowerCase();
          return type == 'food' || type == 'cocktail' || type == 'mocktail';
        }).fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    final double nonTaxableTotal = items.where((item) => item.itemType.toLowerCase() == 'drink')
        .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
        
    final double gstAmount = taxableTotal * 0.05;
    final double subtotal = taxableTotal + nonTaxableTotal;
    final double cgst = gstAmount / 2;
    final double sgst = cgst;
    final double total = subtotal + gstAmount;

    // Load logo if exists
    Uint8List? logoBytes;
    try {
      final logoFile = File('customer_web/MD.png');
      if (logoFile.existsSync()) {
        logoBytes = Uint8List.fromList(logoFile.readAsBytesSync());
      }
    } catch (_) {}

    // Get the next bill number if not already assigned
    int? billNumber = order.billNo;
    if (billNumber == null && title == null) {
      try {
        final response = await Supabase.instance.client
            .from('orders')
            .select('bill_no')
            .order('bill_no', ascending: false)
            .limit(1)
            .maybeSingle();
        
        int lastBillNo = 0;
        if (response != null && response['bill_no'] != null) {
          lastBillNo = response['bill_no'] as int;
        } else {
          final countResponse = await Supabase.instance.client
              .from('orders')
              .select('id')
              .eq('status', 'paid');
          lastBillNo = (countResponse as List).length;
        }

        billNumber = lastBillNo + 1;

        // Save the newly generated incremental bill number back to the database
        await Supabase.instance.client
            .from('orders')
            .update({'bill_no': billNumber})
            .eq('id', order.id);
      } catch (_) {
        billNumber = (order.createdAt.millisecondsSinceEpoch ~/ 1000) % 10000;
      }
    } else if (billNumber == null) {
      // For KOT/BOT (which has title != null), if no bill number is set yet, show placeholder or count-based
      billNumber = (order.createdAt.millisecondsSinceEpoch ~/ 1000) % 10000;
    }
    final String billNoString = 'REG-${billNumber.toString().padLeft(4, '0')}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // 80mm thermal printer width
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        build: (pw.Context context) {
          final bool isKOT = title != null;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (isKOT) ...[
                // Simple KOT / BOT Header
                pw.Center(
                  child: pw.Text(title!.toUpperCase(), 
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 5),
                pw.Text('Order ID: ${order.id.substring(0, 8).toUpperCase()}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(order.createdAt)}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Time: ${DateFormat('hh:mm a').format(order.createdAt)}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Table: ${order.tableName ?? 'Table'}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if (order.customerInfo != null && order.customerInfo!.isNotEmpty)
                  pw.Text('Customer: ${order.customerInfo}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                
                pw.SizedBox(height: 5),
                pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
                
                // 2-Column Heading for Kitchen/Bar
                pw.Row(
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text('Item Name', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
                
                // Bold/Clear Item list for Kitchen/Bar
                ...items.map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text(item.itemName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(child: pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                )),
                
                pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
              ] else ...[
                // Logo
                if (logoBytes != null) ...[
                  pw.Center(
                    child: pw.Container(
                      width: 60,
                      height: 60,
                      child: pw.Image(pw.MemoryImage(logoBytes)),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                ],
                
                // Full Customer Receipt Business Header
                pw.Center(
                  child: pw.Text('MADHULOKA DINING', 
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Center(
                  child: pw.Text('RestoBar & Family Restaurant', 
                    style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
                ),
                pw.Center(
                  child: pw.Text('RC conforts Belur Road Chikmagalur 577101', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Center(
                  child: pw.Text('Ph: 9876543210', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.SizedBox(height: 10),
                
                // Customer Bill Info
                pw.Text('Bill No: $billNoString', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(order.createdAt)}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Time: ${DateFormat('hh:mm a').format(order.createdAt)}', style: const pw.TextStyle(fontSize: 9)),
                if (order.customerInfo != null && order.customerInfo!.isNotEmpty)
                  pw.Text('Customer: ${order.customerInfo}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                
                pw.SizedBox(height: 5),
                pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
                
                // 5-Column Heading with Prices
                pw.Row(
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text('Item Name', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(child: pw.Text('Menu', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(child: pw.Text('Net', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
                
                // Detailed Item list with Prices
                ...items.map((item) {
                  final type = item.itemType.toLowerCase();
                  final bool isTaxable = type == 'food' || type == 'cocktail' || type == 'mocktail';
                  final double originalPrice = item.price;
                  final double taxAddedPrice = isTaxable ? (originalPrice * 1.05) : originalPrice;
                  final double itemTotal = taxAddedPrice * item.quantity;

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        pw.Expanded(flex: 3, child: pw.Text(item.itemName, style: const pw.TextStyle(fontSize: 8))),
                        pw.Expanded(child: pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
                        pw.Expanded(child: pw.Text(originalPrice.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                        pw.Expanded(child: pw.Text(taxAddedPrice.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                        pw.Expanded(child: pw.Text(itemTotal.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                      ],
                    ),
                  );
                }),
                
                pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
                
                // Subtotal, Taxes, Grand Total
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Sub Total:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(subtotal.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('CGST (2.5%):', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(cgst.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SGST (2.5%):', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(sgst.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
                
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                
                pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
                pw.SizedBox(height: 10),
                
                // Business Thank You Footer
                pw.Center(
                  child: pw.Text('THANK YOU!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Center(
                  child: pw.Text('MADHULOKA DINING', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Center(
                  child: pw.Text('Please Visit Again', style: const pw.TextStyle(fontSize: 9)),
                ),
              ],
            ],
          );
        },
      ),
    );

    final String filename = 'Bill_${order.tableName ?? 'Table'}_$billNoString';
    if (context != null) {
      _showPrintPreviewDialog(context, pdf, filename);
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: filename,
      );
    }
  }

  static pw.Widget _buildKotPageContent(String title, OrderModel order, List<OrderItem> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Simple KOT / BOT Header
        pw.Center(
          child: pw.Text(title.toUpperCase(), 
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 5),
        pw.Text('Order ID: ${order.id.substring(0, 8).toUpperCase()}', style: const pw.TextStyle(fontSize: 9)),
        pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(order.createdAt)}', style: const pw.TextStyle(fontSize: 9)),
        pw.Text('Time: ${DateFormat('hh:mm a').format(order.createdAt)}', style: const pw.TextStyle(fontSize: 9)),
        pw.Text('Table: ${order.tableName ?? 'Table'}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        if (order.customerInfo != null && order.customerInfo!.isNotEmpty)
          pw.Text('Customer: ${order.customerInfo}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        
        pw.SizedBox(height: 5),
        pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
        
        // 2-Column Heading for Kitchen/Bar
        pw.Row(
          children: [
            pw.Expanded(flex: 4, child: pw.Text('Item Name', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
        
        // Bold/Clear Item list for Kitchen/Bar
        ...items.map((item) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            children: [
              pw.Expanded(flex: 4, child: pw.Text(item.itemName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
              pw.Expanded(child: pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
            ],
          ),
        )),
        
        pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
      ],
    );
  }

  static Future<void> printKotAndBot(OrderModel order, {BuildContext? context}) async {
    final pdf = pw.Document();

    final foodItems = order.items.where((item) {
      final type = item.itemType.toLowerCase();
      return type == 'food';
    }).toList();

    final drinkItems = order.items.where((item) {
      final type = item.itemType.toLowerCase();
      return type == 'drink' || type == 'cocktail' || type == 'mocktail';
    }).toList();

    // Fallback: If no items are categorized as drinks, print all items as food KOT
    final hasDrinks = drinkItems.isNotEmpty;
    final finalFoodItems = !hasDrinks ? order.items : foodItems;

    bool hasAddedPage = false;

    // Add KOT - FOOD page
    if (finalFoodItems.isNotEmpty) {
      hasAddedPage = true;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          build: (pw.Context context) {
            return _buildKotPageContent('KOT - FOOD', order, finalFoodItems);
          },
        ),
      );
    }

    // Add BOT - DRINKS page
    if (hasDrinks && drinkItems.isNotEmpty) {
      hasAddedPage = true;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          build: (pw.Context context) {
            return _buildKotPageContent('BOT - DRINKS', order, drinkItems);
          },
        ),
      );
    }

    if (!hasAddedPage) return;

    final String filename = 'KOT_BOT_${order.tableName ?? 'Table'}_${order.id.substring(0, 8)}';
    if (context != null) {
      _showPrintPreviewDialog(context, pdf, filename);
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: filename,
      );
    }
  }

  static void _showPrintPreviewDialog(BuildContext context, pw.Document pdf, String filename) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1E1E), // Slate dark theme
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 480,
            height: 750,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Print Preview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange.shade100,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PdfPreview(
                      build: (format) async => pdf.save(),
                      allowPrinting: true,
                      allowSharing: false,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                      pdfFileName: '$filename.pdf',
                      loadingWidget: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
