// Fabricated data only. Does not access the local business database.
import 'dart:io';

import 'package:hesabu/core/customers/customer_analysis.dart';

void main() {
  String q(String s) => '"${s.replaceAll('"', '""')}"';
  String two(int v) => v.toString().padLeft(2, '0');
  final rows = generateCustomerSamples(DateTime.now().toUtc());
  final csv = StringBuffer('Date,Customer Name,Phone,Amount,Sale ID\n');
  for (final p in rows) {
    final d = p.at.toUtc().add(const Duration(hours: 3));
    final date =
        '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
    csv.writeln(
      [
        date,
        p.name,
        p.phone ?? '',
        (p.amount / 100).toStringAsFixed(2),
        p.id.replaceFirst('sale:', ''),
      ].map(q).join(','),
    );
  }
  final folder = Directory('sample_output')..createSync(recursive: true);
  File('${folder.path}/fabricated_customer_sales.csv')
      .writeAsStringSync(csv.toString());
  stdout.writeln(
    'Fabricated customer sales written to sample_output/fabricated_customer_sales.csv. No real data was accessed.',
  );
}
