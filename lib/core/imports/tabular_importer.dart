import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:excel_plus/excel_plus.dart';

enum ImportTarget { sales, expenses }

class CleanImportRow {
  const CleanImportRow({
    required this.sourceRow,
    required this.id,
    required this.date,
    required this.description,
    required this.amountMinor,
    required this.quantity,
    required this.unitPriceMinor,
    required this.category,
    required this.party,
    required this.warnings,
  });

  final int sourceRow;
  final String id;
  final DateTime date;
  final String description;
  final int amountMinor;
  final int quantity;
  final int unitPriceMinor;
  final String category;
  final String party;
  final List<String> warnings;
}

class ImportPreview {
  const ImportPreview({
    required this.target,
    required this.rows,
    required this.errors,
    required this.headers,
  });
  final ImportTarget target;
  final List<CleanImportRow> rows;
  final List<String> errors;
  final List<String> headers;
  bool get canImport => rows.isNotEmpty;
}

/// Reads the first worksheet or a CSV directly from selected bytes. It never
/// writes the source file to a temporary or cache directory.
class TabularImporter {
  const TabularImporter();
  static const maxBytes = 25 * 1024 * 1024;
  static const maxRows = 10000;

  ImportPreview preview(Uint8List bytes, String fileName) {
    if (bytes.isEmpty) {
      throw const FormatException('The selected file is empty.');
    }
    if (bytes.length > maxBytes) {
      throw const FormatException('Choose a file smaller than 25 MB.');
    }
    final extension = fileName.toLowerCase().split('.').last;
    final List<List<String>> table;
    if (extension == 'csv') {
      table = _parseCsv(bytes);
    } else if (extension == 'xlsx' || extension == 'xls') {
      try {
        final book = Excel.decodeBytes(bytes);
        if (book.tables.isEmpty) {
          throw const FormatException('The workbook has no worksheets.');
        }
        final sheet = book[book.tables.keys.first];
        table = sheet.rows
            .map((row) => row.map((cell) => _cellText(cell?.value)).toList())
            .toList();
      } on FormatException {
        rethrow;
      } catch (_) {
        throw const FormatException(
          'This spreadsheet could not be read. Save it as .xlsx or CSV and try again.',
        );
      }
    } else {
      throw const FormatException('Choose an .xlsx, .xls or .csv file.');
    }
    final nonEmpty = table
        .where((row) => row.any((value) => value.trim().isNotEmpty))
        .toList();
    if (nonEmpty.length < 2) {
      throw const FormatException('Add a header row and at least one record.');
    }
    if (nonEmpty.length - 1 > maxRows) {
      throw const FormatException('Import up to 10,000 rows at a time.');
    }
    final header = nonEmpty.first.map(_normal).toList();
    final dateColumn = _find(header, const [
      'date',
      'datetime',
      'transactiondate',
      'saledate',
      'spentat',
    ]);
    final descriptionColumn = _find(header, const [
      'description',
      'item',
      'product',
      'details',
      'particulars',
      'expense',
    ]);
    final amountColumn = _find(header, const [
      'amount',
      'total',
      'totalamount',
      'value',
      'paid',
      'cost',
    ]);
    final quantityColumn = _find(header, const ['quantity', 'qty', 'units']);
    final unitPriceColumn = _find(header, const [
      'unitprice',
      'priceperunit',
      'price',
    ]);
    final categoryColumn = _find(header, const ['category', 'expensecategory']);
    final partyColumn = _find(header, const [
      'customer',
      'customername',
      'supplier',
      'payee',
      'party',
      'name',
    ]);
    if ([dateColumn, descriptionColumn].contains(-1) ||
        (amountColumn == -1 && unitPriceColumn == -1)) {
      throw const FormatException(
        'Headers need a date, a description or product, and an amount or price column.',
      );
    }
    final target =
        (categoryColumn >= 0 ||
            header.any(
              (value) => const ['expense', 'payee', 'supplier'].contains(value),
            ))
        ? ImportTarget.expenses
        : ImportTarget.sales;
    final rows = <CleanImportRow>[];
    final errors = <String>[];
    final fileHash = sha256.convert(bytes).toString().substring(0, 16);
    for (var i = 1; i < nonEmpty.length; i++) {
      final source = nonEmpty[i];
      String field(int index) =>
          index < 0 || index >= source.length ? '' : source[index].trim();
      final date = _parseDate(field(dateColumn));
      final name = field(descriptionColumn);
      final quantity = quantityColumn < 0 || field(quantityColumn).isEmpty
          ? 1
          : int.tryParse(field(quantityColumn));
      final amount = _moneyMinor(field(amountColumn));
      final unitPrice = _moneyMinor(field(unitPriceColumn));
      final price = unitPrice ?? amount;
      final rowErrors = <String>[];
      if (date == null) rowErrors.add('date is missing or invalid');
      if (name.isEmpty) rowErrors.add('description is blank');
      if (quantity == null || quantity <= 0) {
        rowErrors.add('quantity must be a positive whole number');
      }
      if (price == null || price <= 0) {
        rowErrors.add('amount must be positive KES');
      }
      if (amount != null && amount <= 0) {
        rowErrors.add('total amount must be positive KES');
      }
      if (unitPrice != null && unitPrice <= 0) {
        rowErrors.add('unit price must be positive KES');
      }
      if (rowErrors.isNotEmpty) {
        errors.add('Row ${i + 1}: ${rowErrors.join('; ')}.');
        continue;
      }
      final effectiveQuantity = quantity!;
      // A supplied Amount/Total column is treated as the row total; a Price
      // column is treated as a per-unit value when no total is supplied.
      final amountMinor = amount ?? price! * effectiveQuantity;
      rows.add(
        CleanImportRow(
          sourceRow: i + 1,
          id: 'IMPORT-$fileHash-${i + 1}',
          date: date!,
          description: name,
          amountMinor: amountMinor,
          quantity: target == ImportTarget.sales ? effectiveQuantity : 1,
          unitPriceMinor: target == ImportTarget.sales && amount == null
              ? price!
              : target == ImportTarget.sales
              ? (amountMinor / effectiveQuantity).round()
              : amountMinor,
          category: target == ImportTarget.expenses
              ? (categoryColumn >= 0 && field(categoryColumn).isNotEmpty
                    ? field(categoryColumn)
                    : 'Imported expense')
              : '',
          party: field(partyColumn),
          warnings: const [],
        ),
      );
    }
    if (rows.isEmpty && errors.isNotEmpty) {
      throw FormatException('No valid rows found. ${errors.first}');
    }
    return ImportPreview(
      target: target,
      rows: rows,
      errors: errors,
      headers: nonEmpty.first,
    );
  }
}

int _find(List<String> headers, List<String> names) =>
    headers.indexWhere(names.contains);

String _normal(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _cellText(CellValue? value) {
  if (value == null) return '';
  if (value is TextCellValue) return value.value.toString();
  if (value is IntCellValue) return '${value.value}';
  if (value is DoubleCellValue) return '${value.value}';
  if (value is BoolCellValue) return '${value.value}';
  if (value is DateCellValue) {
    return '${value.year}-${value.month}-${value.day}';
  }
  if (value is DateTimeCellValue) {
    return '${value.year}-${value.month}-${value.day}';
  }
  if (value is TimeCellValue) {
    return '${value.hour}:${value.minute}:${value.second}';
  }
  if (value is CellErrorValue) return value.value;
  if (value is FormulaCellValue) return value.cachedValue ?? '';
  return '$value';
}

DateTime? _parseDate(String text) {
  final value = text.trim();
  if (value.isEmpty) return null;
  final iso = DateTime.tryParse(value);
  if (iso != null) return DateTime.utc(iso.year, iso.month, iso.day);
  final match = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$')
      .firstMatch(value);
  if (match == null) return null;
  final day = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final year = int.parse(match[3]!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime.utc(year, month, day);
  return date.day == day && date.month == month ? date : null;
}

int? _moneyMinor(String text) {
  final cleaned = text
      .replaceAll(',', '')
      .replaceAll(RegExp(r'KES|KSh|\s', caseSensitive: false), '')
      .replaceAll('(', '-')
      .replaceAll(')', '');
  final value = double.tryParse(cleaned);
  if (value == null || !value.isFinite) return null;
  return (value * 100).round();
}

/// Strict enough for ordinary CSVs while supporting quoted commas and escaped
/// quotes. It returns rows in memory only and never writes a raw import.
List<List<String>> _parseCsv(Uint8List bytes) {
  String input;
  try {
    input = utf8.decode(bytes).replaceFirst('\ufeff', '');
  } catch (_) {
    throw const FormatException('Save CSV as UTF-8 and try again.');
  }
  final firstLine = input.split(RegExp(r'\r?\n')).first;
  final delimiter =
      ';'.allMatches(firstLine).length > ','.allMatches(firstLine).length
      ? ';'
      : ',';
  final result = <List<String>>[];
  var row = <String>[];
  var field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char == '"') {
      if (quoted && i + 1 < input.length && input[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (!quoted && (char == delimiter || char == '\r' || char == '\n')) {
      row.add(field.toString());
      field = StringBuffer();
      if (char != delimiter) {
        if (row.any((value) => value.trim().isNotEmpty)) result.add(row);
        row = [];
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      }
    } else {
      field.write(char);
    }
  }
  if (quoted) throw const FormatException('CSV contains an unclosed quote.');
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    result.add(row);
  }
  return result;
}
