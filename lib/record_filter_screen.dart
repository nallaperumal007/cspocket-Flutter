import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';

class RecordFilterScreen extends StatefulWidget {
  const RecordFilterScreen({Key? key}) : super(key: key);

  @override
  _RecordFilterScreenState createState() => _RecordFilterScreenState();
}

class _RecordFilterScreenState extends State<RecordFilterScreen> {
  DateTime? startDate;
  DateTime? endDate;
  List<Map<String, dynamic>> records = [];

  void _filterRecords() async {
    if (startDate == null || endDate == null) return;

    final startTimestamp = Timestamp.fromDate(startDate!);
    final endTimestamp = Timestamp.fromDate(endDate!);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('entry')
          .where('bdt', isGreaterThanOrEqualTo: startTimestamp)
          .where('bdt', isLessThanOrEqualTo: endTimestamp)
          .get();

      setState(() {
        records = querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      });
      print('Records fetched: ${records.length}');
    } catch (e) {
      print('Error fetching records: $e');
    }
  }

  void _exportToPDF() async {
    final pdf = pw.Document();

    if (records.isNotEmpty) {
      final headers = records.first.keys.toList();
      final data = records.map((record) => headers.map((header) => record[header]).toList()).toList();

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Table.fromTextArray(headers: headers, data: data),
        ),
      );
    }

    final bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'records.pdf')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  void _exportToCSV() {
    if (records.isNotEmpty) {
      final headers = records.first.keys.toList();
      final data = records.map((record) => headers.map((header) => record[header]?.toString() ?? '').toList()).toList();
      final csvData = const ListToCsvConverter().convert([headers, ...data]);

      final blob = html.Blob([csvData], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'records.csv')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  void _printRecords() async {
    final pdf = pw.Document();

    if (records.isNotEmpty) {
      final headers = records.first.keys.toList();
      final data = records.map((record) => headers.map((header) => record[header]).toList()).toList();

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Table.fromTextArray(headers: headers, data: data),
        ),
      );
    }

    final bytes = await pdf.save();
    Printing.layoutPdf(onLayout: (format) async => bytes);
  }

  Future<void> _pickDate(BuildContext context, bool isStart) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      setState(() {
        if (isStart) {
          startDate = pickedDate;
        } else {
          endDate = pickedDate;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Filtered Records'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(context, true),
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: startDate == null
                              ? 'Start Date'
                              : startDate.toString().substring(0, 10),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(context, false),
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: endDate == null
                              ? 'End Date'
                              : endDate.toString().substring(0, 10),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _filterRecords,
                  child: Text('Generate'),
                ),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: records.isEmpty
                  ? Center(child: Text('No records found'))
                  : ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text('Record ${index + 1}'),
                            subtitle: Text(record.toString()),
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _exportToPDF,
                  icon: Icon(Icons.picture_as_pdf),
                  label: Text('Export to PDF'),
                ),
                ElevatedButton.icon(
                  onPressed: _exportToCSV,
                  icon: Icon(Icons.download),
                  label: Text('Export to CSV'),
                ),
                ElevatedButton.icon(
                  onPressed: _printRecords,
                  icon: Icon(Icons.print),
                  label: Text('Print'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
