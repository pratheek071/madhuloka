import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/order_model.dart';
import '../../models/order_item_model.dart';
import 'package:intl/intl.dart';

class BillingService {
  static Future<void> printInvoice(OrderModel order, {String? title, List<OrderItem>? customItems}) async {
    final pdf = pw.Document();
    final items = customItems ?? order.items;

    final double foodTotal = items.where((item) => item.itemType.toLowerCase() == 'food')
        .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    final double drinkTotal = items.where((item) => item.itemType.toLowerCase() == 'drink')
        .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
        
    final double foodSubtotal = foodTotal / 1.05;
    final double gstAmount = foodTotal - foodSubtotal;
    final double subtotal = foodSubtotal + drinkTotal;
    final double cgst = gstAmount / 2;
    final double sgst = cgst;
    final double total = foodTotal + drinkTotal;

    // Load logo if exists
    final logoFile = File('customer_web/MD.png');
    final logoBytes = logoFile.existsSync() ? logoFile.readAsBytesSync() : null;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // 80mm thermal printer width
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
            return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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
              
              // Header
              pw.Center(
                child: pw.Text('MADHULOKA DINING', 
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(
                child: pw.Text('RestoBar & Family Restaurant', 
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
              ),
              pw.Center(
                child: pw.Text('123 Main Road, Bangalore', style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.Center(
                child: pw.Text('Ph: 9876543210', style: const pw.TextStyle(fontSize: 8)),
              ),
              if (title != null) ...[
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(title.toUpperCase(), 
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ),
              ],
              pw.SizedBox(height: 10),
              
              // Bill Info
              pw.Text('Bill No: REG-${order.id.substring(0, 5).toUpperCase()}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(order.createdAt)}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Time: ${DateFormat('hh:mm a').format(order.createdAt)}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Table: ${order.tableName ?? 'Table'}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              if (order.customerInfo != null && order.customerInfo!.isNotEmpty)
                pw.Text('Customer: ${order.customerInfo}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              
              pw.SizedBox(height: 5),
              pw.Text('------------------------------------------', style: const pw.TextStyle(fontSize: 10)), // Dotted line effect
              
              // Headings
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Item Name', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(child: pw.Text('Price', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Text('------------------------------------------', style: const pw.TextStyle(fontSize: 10)),
              
              // Items List
              ...items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text(item.itemName, style: const pw.TextStyle(fontSize: 9))),
                    pw.Expanded(child: pw.Text(item.quantity.toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9))),
                    pw.Expanded(child: pw.Text(item.price.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                    pw.Expanded(child: pw.Text((item.price * item.quantity).toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                  ],
                ),
              )),
              
              pw.Text('------------------------------------------', style: const pw.TextStyle(fontSize: 10)),
              
              // Totals
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
              pw.Text('------------------------------------------', style: const pw.TextStyle(fontSize: 10)),
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rs ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              
              pw.Text('------------------------------------------', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 10),
              
              // Footer
              pw.Center(
                child: pw.Text('THANK YOU!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(
                child: pw.Text('MADHULOKA DINING', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(
                child: pw.Text('Please Visit Again', style: const pw.TextStyle(fontSize: 9)),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text('GSTIN: 29AAAAA0000A1Z5', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ),
            ],
          );
        },
      ),
    );

    // This opens the system print dialog which supports both Windows and Mac
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Bill_${order.tableName ?? 'Table'}_${order.id.substring(0, 5)}',
    );
  }
}
