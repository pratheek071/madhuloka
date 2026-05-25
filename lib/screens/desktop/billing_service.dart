import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/order_model.dart';
import '../../models/order_item_model.dart';
import '../../services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/restaurant_provider.dart';


class BillingService {
  static pw.Document _generateInvoicePdf(OrderModel order, int? billNumber, {List<OrderItem>? customItems}) {
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
    final double total = subtotal + gstAmount;
    final double discountPercent = order.discount;
    final double discountAmount = total * (discountPercent / 100);
    final double finalTotal = total - discountAmount;

    final String billNoString = billNumber != null 
        ? 'REG-${billNumber.toString().padLeft(4, '0')}' 
        : 'PENDING';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // 80mm thermal printer width
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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
              pw.SizedBox(height: 10),
              
              // Customer Bill Info
              pw.Text('Bill No: $billNoString', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Date: ${DateFormat('dd-MM-yyyy').format(order.createdAt)}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Time: ${DateFormat('hh:mm a').format(order.createdAt)}', style: const pw.TextStyle(fontSize: 9)),
              if (order.customerInfo != null && order.customerInfo!.isNotEmpty)
                pw.Text('Customer: ${order.customerInfo}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
              
              // 4-Column Receipt Grid
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Item Name', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Price', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 3, child: pw.Text('Total (Inc Tax)', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400, height: 8),
              
              // Item Rows
              ...items.map((item) {
                final type = item.itemType.toLowerCase();
                final isTaxed = type == 'food' || type == 'cocktail' || type == 'mocktail';
                
                final double rate = item.price;
                final double taxRate = isTaxed ? (item.price * 1.05) : item.price;
                final double totalLinePrice = taxRate * item.quantity;
                
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(item.itemName, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Expanded(flex: 2, child: pw.Text(rate.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Expanded(flex: 3, child: pw.Text(totalLinePrice.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                    ],
                  ),
                );
              }),
              
              pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
              
              // Subtotal, Taxes, Grand Total (CGST & SGST removed per request)
              if (discountPercent > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total (Incl. Tax):', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(total.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount (${discountPercent.toStringAsFixed(0)}%):', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('-${discountAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
              ],
              
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GRAND TOTAL:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Rs ${finalTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              
              pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
              pw.SizedBox(height: 10),
              
              // Business Thank You Footer
              pw.Center(
                child: pw.Text('THANK YOU!', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(
                child: pw.Text('Please Visit Again', style: const pw.TextStyle(fontSize: 9)),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static Future<void> printInvoice(OrderModel order, {BuildContext? context, String? title, List<OrderItem>? customItems}) async {
    int? billNumber = order.billNo;
    
    // Only generate the bill number on direct print (context == null).
    // If context != null, we display PENDING on the preview and generate it only when they print.
    if (context == null && billNumber == null) {
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
    }

    final pdf = _generateInvoicePdf(order, billNumber, customItems: customItems);

    final String billNoString = billNumber != null 
        ? 'REG-${billNumber.toString().padLeft(4, '0')}' 
        : 'PENDING';
    final String filename = 'Bill_${order.tableName ?? 'Table'}_$billNoString';

    if (context != null) {
      if (context.mounted) {
        _showPrintPreviewDialog(
          context, 
          pdf, 
          filename, 
          invoiceOrder: order, 
          customItems: customItems,
        );
      }
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
        pw.Text(
          order.isParcel ? 'Type: PARCEL' : 'Table: ${order.tableName ?? 'Table'}',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
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

  static Future<void> printKotAndBot(OrderModel order, {BuildContext? context, bool forcePrintAll = false}) async {
    final newItemsToPrint = forcePrintAll
        ? order.items
        : order.items
            .where((item) => (item.quantity - item.printedQuantity) > 0)
            .map((item) => OrderItem(
                id: item.id,
                orderId: item.orderId,
                menuItemId: item.menuItemId,
                itemName: item.itemName,
                quantity: item.quantity - item.printedQuantity,
                printedQuantity: item.printedQuantity,
                price: item.price,
                itemType: item.itemType))
            .toList();

    if (newItemsToPrint.isEmpty) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No new items to print for KOT/BOT.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final foodItems = newItemsToPrint.where((item) {
      final type = item.itemType.toLowerCase();
      return type == 'food';
    }).toList();

    final drinkItems = newItemsToPrint.where((item) {
      final type = item.itemType.toLowerCase();
      return type == 'drink' || type == 'cocktail' || type == 'mocktail';
    }).toList();

    final hasDrinks = drinkItems.isNotEmpty;
    final finalFoodItems = !hasDrinks ? newItemsToPrint : foodItems;

    final List<pw.Document> printJobs = [];
    final combinedPdf = pw.Document();
    bool hasAddedPage = false;

    // KOT - FOOD
    if (finalFoodItems.isNotEmpty) {
      hasAddedPage = true;
      final kotPdf = pw.Document();
      final page = pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        build: (pw.Context context) {
          return _buildKotPageContent('KOT - FOOD', order, finalFoodItems);
        },
      );
      kotPdf.addPage(page);
      combinedPdf.addPage(page);
      printJobs.add(kotPdf);
    }

    // BOT - DRINKS
    if (hasDrinks && drinkItems.isNotEmpty) {
      hasAddedPage = true;
      final botPdf = pw.Document();
      final page = pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        build: (pw.Context context) {
          return _buildKotPageContent('BOT - DRINKS', order, drinkItems);
        },
      );
      botPdf.addPage(page);
      combinedPdf.addPage(page);
      printJobs.add(botPdf);
    }

    if (!hasAddedPage) return;

    final String filename = 'KOT_BOT_${order.tableName ?? 'Table'}_${order.id.substring(0, 8)}';
    if (context != null) {
      _showPrintPreviewDialog(context, combinedPdf, filename, separateJobs: printJobs, orderToMark: forcePrintAll ? null : order);
    } else {
      for (var job in printJobs) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => job.save(),
          name: filename,
        );
      }
      if (!forcePrintAll) {
        await SupabaseService().markOrderAsPrinted(order.id);
      }
    }
  }

  static void _showPrintPreviewDialog(
    BuildContext context, 
    pw.Document pdf, 
    String filename, {
    List<pw.Document>? separateJobs, 
    OrderModel? orderToMark,
    OrderModel? invoiceOrder,
    List<OrderItem>? customItems,
  }) {
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
                      allowPrinting: false, // Override printing with our custom actions
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
                      actions: [
                        PdfPreviewAction(
                          icon: const Icon(Icons.print),
                          onPressed: (ctx, build, pageFormat) async {
                            if (invoiceOrder != null) {
                              int billNumber;
                              try {
                                final currentOrder = await Supabase.instance.client
                                    .from('orders')
                                    .select('bill_no')
                                    .eq('id', invoiceOrder.id)
                                    .single();
                                
                                if (currentOrder['bill_no'] != null) {
                                  billNumber = currentOrder['bill_no'] as int;
                                } else {
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
                                  
                                  await Supabase.instance.client
                                      .from('orders')
                                      .update({'bill_no': billNumber})
                                      .eq('id', invoiceOrder.id);
                                }
                              } catch (e) {
                                billNumber = (invoiceOrder.createdAt.millisecondsSinceEpoch ~/ 1000) % 10000;
                              }

                              final actualPdf = _generateInvoicePdf(
                                invoiceOrder, 
                                billNumber, 
                                customItems: customItems,
                              );

                              await Printing.layoutPdf(
                                onLayout: (PdfPageFormat format) async => actualPdf.save(),
                                name: 'Bill_${invoiceOrder.tableName ?? 'Table'}_REG-${billNumber.toString().padLeft(4, '0')}',
                              );

                              if (context.mounted) {
                                Navigator.of(dialogContext).pop();
                                context.read<RestaurantProvider>().fetchData();
                              }
                            } else if (separateJobs != null) {
                              final printer = await Printing.pickPrinter(context: context);
                              if (printer != null) {
                                for (int i = 0; i < separateJobs.length; i++) {
                                  await Printing.directPrintPdf(
                                    printer: printer,
                                    onLayout: (format) async => separateJobs[i].save(),
                                    name: '${filename}_part$i',
                                  );
                                }
                                if (orderToMark != null) {
                                  await SupabaseService().markOrderAsPrinted(orderToMark.id);
                                  if (context.mounted) {
                                    context.read<RestaurantProvider>().fetchData();
                                  }
                                }
                                if (context.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }
                              }
                            } else {
                              await Printing.layoutPdf(
                                onLayout: (PdfPageFormat format) async => pdf.save(),
                                name: filename,
                              );
                              if (context.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            }
                          },
                        ),
                      ],
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

  static Future<void> printBestSellingItemsReport(
      DateTime start, DateTime end, List<MapEntry<String, int>> sortedItems,
      {required BuildContext context}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('MADHULOKA DINING', 
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(
                child: pw.Text('BEST SELLING ITEMS REPORT', 
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  'Period: ${DateFormat('dd-MM-yyyy').format(start)} to ${DateFormat('dd-MM-yyyy').format(end)}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
              
              // Column Headers
              pw.Row(
                children: [
                  pw.Expanded(flex: 1, child: pw.Text('Rank', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 4, child: pw.Text('Item Description', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Qty Sold', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400, height: 8),
              
              // Item Rows
              ...sortedItems.asMap().entries.map((entry) {
                final int idx = entry.key;
                final MapEntry<String, int> item = entry.value;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 1, child: pw.Text('${idx + 1}', style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Expanded(flex: 4, child: pw.Text(item.key, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Expanded(flex: 2, child: pw.Text('${item.value}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                    ],
                  ),
                );
              }),
              
              pw.Divider(thickness: 0.8, color: PdfColors.grey600, height: 10),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text('End of Report', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
              ),
            ],
          );
        },
      ),
    );

    final String filename = 'Best_Selling_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}';
    _showPrintPreviewDialog(context, pdf, filename);
  }

  static Future<void> printSalesReport(
    DateTime start, 
    DateTime end, 
    List<OrderModel> orders, 
    String paymentFilter, {
    required BuildContext context,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('MADHULOKA DINING', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text('SALES REPORT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Period: ${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.Text(
                  'Payment Filter: $paymentFilter • Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (pw.Context ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (pw.Context ctx) {
          // Calculate summary totals
          final totalRevenue = orders.fold(0.0, (sum, o) => sum + o.finalAmount);
          final totalDiscount = orders.fold(0.0, (sum, o) => sum + o.discountAmount);
          
          return [
            // Summary Cards
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: [
                _buildPdfSummaryCard('Total Orders', '${orders.length}', PdfColors.blue),
                pw.SizedBox(width: 16),
                _buildPdfSummaryCard('Total Discounts', '₹${totalDiscount.toStringAsFixed(2)}', PdfColors.purple),
                pw.SizedBox(width: 16),
                _buildPdfSummaryCard('Total Revenue', '₹${totalRevenue.toStringAsFixed(2)}', PdfColors.green),
              ],
            ),
            pw.SizedBox(height: 20),
            
            // Sales Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.2), // Bill No
                1: pw.FlexColumnWidth(2),   // Date/Time
                2: pw.FlexColumnWidth(2),   // Table/Info
                3: pw.FlexColumnWidth(1.2), // Source
                4: pw.FlexColumnWidth(1),   // Items Qty
                5: pw.FlexColumnWidth(1.5), // Discount
                6: pw.FlexColumnWidth(1.8), // Net Amount
                7: pw.FlexColumnWidth(1.5), // Payment
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildTableHeaderCell('BILL NO'),
                    _buildTableHeaderCell('DATE & TIME'),
                    _buildTableHeaderCell('TABLE / INFO'),
                    _buildTableHeaderCell('SOURCE'),
                    _buildTableHeaderCell('ITEMS'),
                    _buildTableHeaderCell('DISCOUNT'),
                    _buildTableHeaderCell('AMOUNT'),
                    _buildTableHeaderCell('PAYMENT'),
                  ],
                ),
                // Data Rows
                ...orders.map((order) {
                  return pw.TableRow(
                    children: [
                      _buildTableCell(order.billNo != null ? 'REG-${order.billNo.toString().padLeft(4, '0')}' : 'N/A', alignLeft: true, isBold: true),
                      _buildTableCell(DateFormat('dd MMM yyyy, hh:mm a').format(order.completedAt ?? order.createdAt)),
                      _buildTableCell(order.isParcel ? 'Parcel: ${order.customerInfo ?? "N/A"}' : (order.tableName ?? 'Table')),
                      _buildTableCell(order.orderSource.toUpperCase()),
                      _buildTableCell('${order.items.length}'),
                      _buildTableCell('₹${order.discountAmount.toStringAsFixed(2)}'),
                      _buildTableCell('₹${order.finalAmount.toStringAsFixed(2)}', isBold: true),
                      _buildTableCell((order.paymentMethod ?? 'PAID').toUpperCase(), isBold: true),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    final String filename = 'Sales_Report_${DateFormat('yyyyMMdd').format(start)}_${DateFormat('yyyyMMdd').format(end)}';
    if (context.mounted) {
      _showPrintPreviewDialog(context, pdf, filename);
    }
  }

  static pw.Widget _buildPdfSummaryCard(String title, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool alignLeft = false, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
      ),
    );
  }
}

