// Generates fabricated files only. Real statements must never be supplied here.
import 'dart:convert';
import 'dart:io';

import 'package:bizlens/core/sample_data.dart';

Future<void> main(List<String> args) async {
  final directory = Directory('sample_output')..createSync(recursive: true);
  await File('${directory.path}/fabricated_mpesa.csv')
      .writeAsBytes(generateSampleMpesaCsv());
  if (args.contains('--pdf-source')) {
    await File('${directory.path}/fabricated_rows.json').writeAsString(
      jsonEncode(
        generateSampleMpesaTransactions()
            .map((v) => {...v.toJson(), 'localDate': fixtureDate(v.at)})
            .toList(),
      ),
    );
  }
  if (generateSampleMpesaPdf().isNotEmpty) {
    await File('${directory.path}/fabricated_mpesa_protected.pdf')
        .writeAsBytes(generateSampleMpesaPdf());
  }
  stdout.writeln(
    'Fabricated samples written to sample_output. PDF fixture password: $sampleMpesaPassword',
  );
}
