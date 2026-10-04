import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../model/booking.dart';

/// Builds and opens the print/share sheet for a ride or parcel invoice.
Future<void> showBookingInvoice(Booking booking, {required String customerName, required String customerPhone}) async {
  // Inter has the ₹ glyph; the PDF default font does not.
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter-Bold.ttf'));
  final logo = await imageFromAssetBundle('assets/images/gologo.png');

  final isRide = booking.kind == BookingKind.ride;
  final when = booking.pickupDateTime;
  final rider = booking.rider;
  const teal = PdfColor.fromInt(0xFF159A9C);
  const navy = PdfColor.fromInt(0xFF16324F);

  pw.TableRow row(String label, String? value) => pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(label, style: pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.grey700)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text((value == null || value.isEmpty) ? '-' : value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      );

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Image(logo, height: 40),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('INVOICE', style: pw.TextStyle(font: bold, fontSize: 20, color: navy)),
                  pw.Text('#${booking.id}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  if (when != null)
                    pw.Text(DateFormat('dd MMM yyyy, hh:mm a').format(when), style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Invoice to', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  pw.Text(customerName, style: pw.TextStyle(font: bold)),
                  pw.Text('+91 $customerPhone'),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Service', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  pw.Text(isRide ? 'Rider Booking' : 'Parcel Delivery', style: pw.TextStyle(font: bold)),
                  pw.Text('Gotan, Rajasthan'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            width: double.infinity,
            color: teal,
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text('Trip details', style: pw.TextStyle(font: bold, color: PdfColors.white)),
          ),
          pw.Table(
            columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(5)},
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              row('Pickup', booking.pickup),
              row('Drop', booking.drop),
              row('Distance', booking.distance),
              if (isRide) row('Vehicle', booking.vehicleType),
              if (isRide) row('Passengers', booking.passengers),
              if (!isRide) row('Weight', booking.weight),
              if (!isRide) row('Package', booking.message),
              row('Rider', rider?.name),
              row('Rider phone', rider?.phone),
              row('Status', booking.stageLabel),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFFDDF3F2), borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Text(
                'Total (paid to rider): ₹${booking.expectedPrice.isEmpty ? '-' : booking.expectedPrice}',
                style: pw.TextStyle(font: bold, fontSize: 13, color: navy),
              ),
            ),
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.Text('Thank you for choosing Gotan', style: pw.TextStyle(font: bold, color: teal)),
          pw.SizedBox(height: 4),
          pw.Text(
            'Siyag Rural Market Private Limited [© Digistall] · CIN U52100RJ2021PTC077111 · GSTIN 08ABGCS8909L1ZN',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    ),
  );

  await Printing.layoutPdf(name: 'gotan-${booking.id}.pdf', onLayout: (_) async => doc.save());
}
