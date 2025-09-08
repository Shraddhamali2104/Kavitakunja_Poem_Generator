import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';

class GrnPdfLayout {
  static pw.Font? fontRegular;
  static pw.Font? fontBold;

  /// Load fonts once
  static Future<void> _loadFonts() async {
    fontRegular ??= pw.Font.ttf(
      await rootBundle.load("assets/fonts/NotoSans-Regular.ttf"),
    );
    fontBold ??= pw.Font.ttf(
      await rootBundle.load("assets/fonts/NotoSans-Bold.ttf"),
    );
  }

  /// Fetch supplier details from API
  static Future<Map<String, dynamic>?> fetchSupplier(int supplierId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token'); // token stored in prefs

    final url = Uri.parse(
      "https://1.sunshineiot.in/api/v2/purchase/supplier/$supplierId",
    );

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      try {
        return json.decode(response.body);
      } catch (e) {
        print("Invalid JSON: ${response.body}");
        return null;
      }
    } else {
      print(
        "Failed to fetch supplier details: ${response.statusCode} - ${response.body}",
      );
      return null;
    }
  }

  /// Convert number to words (basic helper)
  static String numberToWords(int number) {
    return "$number INR Only"; // placeholder
  }

  /// Generate PDF bytes for GRN
  static Future<Uint8List> generatePdf(Map<String, dynamic> apiData) async {
    await _loadFonts();
    final pdf = pw.Document();

    // Fetch supplier details
    Map<String, dynamic>? supplierData = await fetchSupplier(
      apiData['supplier_id'],
    );
    final supplierJson = supplierData?['data'] ?? supplierData;
    final supplierAddress =
        (supplierJson != null &&
            supplierJson['addresses'] != null &&
            supplierJson['addresses'].isNotEmpty)
        ? supplierJson['addresses'][0]
        : null;

    final totalAmount = (apiData['billing_amount'] ?? 0).toString();
    final amountInWords = numberToWords(
      int.tryParse(apiData['billing_amount'].toString()) ?? 0,
    );

    final baseStyle = pw.TextStyle(
      font: fontRegular,
      fontFallback: [fontRegular!],
      fontSize: 9,
    );
    final boldStyle = pw.TextStyle(
      font: fontBold,
      fontFallback: [fontRegular!],
      fontSize: 9,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Title
            pw.Center(
              child: pw.Text(
                "GOODS RECEIPT NOTE",
                style: boldStyle.copyWith(fontSize: 16),
              ),
            ),
            pw.SizedBox(height: 15),

            // Partitioned Header (Invoicee, Consignee, Supplier)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 1),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: [
                    // Invoice To
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Invoice To", style: boldStyle),
                          pw.Text(
                            "Sunshine Powertronics Pvt Ltd",
                            style: baseStyle,
                          ),
                          pw.Text(
                            "Survey no-155, Gajraj Heights, First Floor",
                            style: baseStyle,
                          ),
                          pw.Text(
                            "Manjari Road, Near Kalyani School, Manjari Bk",
                            style: baseStyle,
                          ),
                          pw.Text("Pune, Pin-412307", style: baseStyle),
                          pw.Text(
                            "GSTIN/UIN: 27AAWCS1432K1ZV",
                            style: baseStyle,
                          ),
                          pw.Text(
                            "State Name : Maharashtra, Code : 27",
                            style: baseStyle,
                          ),
                          pw.Text(
                            "E-Mail : sunil.c@sunshinepowertronics.com",
                            style: baseStyle,
                          ),
                        ],
                      ),
                    ),

                    // Consignee
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Consignee (Ship to)", style: boldStyle),
                          pw.Text(
                            "Sunshine Powertronics Pvt Ltd",
                            style: baseStyle,
                          ),
                          pw.Text(
                            "Survey no-155, Gajraj Heights, First Floor",
                            style: baseStyle,
                          ),
                          pw.Text(
                            "Manjari Road, Near Kalyani School, Manjari Bk",
                            style: baseStyle,
                          ),
                          pw.Text("Pune, Pin-412307", style: baseStyle),
                          pw.Text(
                            "GSTIN/UIN: 27AAWCS1432K1ZV",
                            style: baseStyle,
                          ),
                          pw.Text(
                            "State Name : Maharashtra, Code : 27",
                            style: baseStyle,
                          ),
                          pw.Text(
                            "E-Mail : sunil.c@sunshinepowertronics.com",
                            style: baseStyle,
                          ),
                        ],
                      ),
                    ),

                    // Supplier
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Supplier (Bill from)", style: boldStyle),
                          pw.Text(
                            supplierJson?['company_name'] ?? "N/A",
                            style: baseStyle,
                          ),
                          if (supplierAddress != null) ...[
                            pw.Text(
                              supplierAddress['address_line1'] ?? "",
                              style: baseStyle,
                            ),
                            pw.Text(
                              supplierAddress['address_line2'] ?? "",
                              style: baseStyle,
                            ),
                            pw.Text(
                              "${supplierAddress['city']}, ${supplierAddress['state']}",
                              style: baseStyle,
                            ),
                            pw.Text(
                              "Pin: ${supplierAddress['pincode']}, ${supplierAddress['country']}",
                              style: baseStyle,
                            ),
                            pw.Text(
                              "GSTIN/UIN: ${supplierAddress['gst_no'] ?? ''}",
                              style: baseStyle,
                            ),
                            pw.Text(
                              "State Name : ${supplierAddress['state'] ?? ''}",
                              style: baseStyle,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            // GRN Info
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 1),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        "GRN No: ${apiData['grn_no']}",
                        style: baseStyle,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        "Date: ${apiData['grn_date'].toString().substring(0, 10)}",
                        style: baseStyle,
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        "Invoice No: ${apiData['invoice_no'] ?? ''}",
                        style: baseStyle,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        "Invoice Date: ${apiData['invoice_date'].toString().substring(0, 10)}",
                        style: baseStyle,
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        "PO No: ${apiData['po_no'] ?? ''}",
                        style: baseStyle,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text("", style: baseStyle),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            // Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 1),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text("Sl No", style: boldStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text("Description of Goods", style: boldStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text("Quantity", style: boldStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text("Rate", style: boldStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text("Amount", style: boldStyle),
                    ),
                  ],
                ),
                ...((apiData['items'] as List).asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(idx.toString(), style: baseStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          item['description'] ??
                              item['item_desc'] ??
                              item['product_name'] ??
                              "",
                          style: baseStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          item['actual_qty']?.toString() ?? "",
                          style: baseStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          item['rate']?.toString() ?? "",
                          style: baseStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          item['invoice_total']?.toString() ?? "",
                          style: baseStyle,
                        ),
                      ),
                    ],
                  );
                })),
              ],
            ),
            pw.SizedBox(height: 10),

            // Taxes
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  "Input IGST 18% : ${apiData['igst_amount'] ?? '0.00'}",
                  style: baseStyle,
                ),
              ],
            ),
            pw.SizedBox(height: 5),

            // Grand Total
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  "Total : ₹$totalAmount",
                  style: boldStyle.copyWith(fontSize: 12),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            pw.Text("Amount Chargeable (in words):", style: baseStyle),
            pw.Text(amountInWords, style: boldStyle),

            pw.SizedBox(height: 20),

            // Declaration
            pw.Text("Declaration", style: boldStyle),
            pw.Bullet(text: "Taxes at actual", style: baseStyle),
            pw.Bullet(
              text: "Packing & Shipping - at Your scope.",
              style: baseStyle,
            ),
            pw.Bullet(
              text:
                  "Inform us in advance if you are unable to ship material within specified time frame",
              style: baseStyle,
            ),
            pw.Text("E. & O.E", style: baseStyle),

            pw.SizedBox(height: 30),

            // Signature
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "For Sunshine Powertronics Pvt Ltd\n\nAuthorised Signatory",
                style: baseStyle,
                textAlign: pw.TextAlign.right,
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Open PDF in browser tab
  static Future<void> openPdfInNewTab(Map<String, dynamic> apiData) async {
    final pdfBytes = await generatePdf(apiData);
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, "_blank");

    Future.delayed(const Duration(seconds: 2), () {
      html.Url.revokeObjectUrl(url);
    });
  }
}
