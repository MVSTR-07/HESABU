import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../mpesa/statement_parser.dart' show parseMoney, parseStatementDate;
import 'customer_analysis.dart';

/// Small strict RFC-style reader. Never writes a plaintext import or logs rows.
class CustomerSalesParser {
  const CustomerSalesParser();
  List<CustomerPayment> parse(Uint8List bytes) {
    if (bytes.isEmpty) throw const FormatException('The CSV is empty.');
    if (bytes.length > 25 * 1024 * 1024) {
      throw const FormatException('Sales CSV exceeds 25 MB.');
    }
    String text;
    try {
      text = utf8.decode(bytes).replaceFirst('\ufeff', '');
    } catch (_) {
      throw const FormatException('Use UTF-8 CSV for sales imports.');
    }
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    var closed = false;
    final firstLine = text.split(RegExp(r'\r?\n')).first;
    final delimiter =
        ';'.allMatches(firstLine).length > ','.allMatches(firstLine).length
        ? ';'
        : ',';
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '"') {
        if (quoted && i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else if (quoted) {
          quoted = false;
          closed = true;
        } else if (field.isEmpty && !closed) {
          quoted = true;
        } else {
          throw const FormatException(
            'Malformed CSV quotes. Export a fresh CSV.',
          );
        }
      } else if (!quoted && (c == delimiter || c == '\n' || c == '\r')) {
        row.add(field.toString());
        field = StringBuffer();
        closed = false;
        if (c != delimiter) {
          if (row.any((v) => v.trim().isNotEmpty)) rows.add(row);
          row = [];
          if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        }
      } else {
        if (closed && c.trim().isNotEmpty) {
          throw const FormatException('Malformed CSV field.');
        }
        if (!closed) field.write(c);
      }
    }
    if (quoted) {
      throw const FormatException('CSV has an unclosed quoted field.');
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    if (rows.length < 2) {
      throw const FormatException('CSV needs a header and completed sales.');
    }
    String normal(String v) =>
        v.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final header = rows.first.map(normal).toList();
    int column(List<String> names) => header.indexWhere(names.contains);
    final date = column(['date', 'datetime', 'paymentdate']),
        name = column(['customer', 'customername', 'name']),
        phone = column(['phone', 'phonenumber', 'mobile']),
        amount = column(['amount', 'paidin', 'total']),
        sale = column(['saleid', 'receipt', 'receiptno', 'invoiceid']);
    if (date < 0 || amount < 0 || (name < 0 && phone < 0)) {
      throw const FormatException(
        'Expected Date, Customer Name and/or Phone, Amount; Sale ID is optional.',
      );
    }
    final payments = <CustomerPayment>[];
    for (var i = 1; i < rows.length; i++) {
      if (payments.length >= 50000) {
        throw const FormatException('Import at most 50,000 sales at a time.');
      }
      String cell(int c) =>
          c < 0 ? '' : (c < rows[i].length ? rows[i][c].trim() : '');
      if (rows[i].length != header.length) {
        throw FormatException(
          'Sales row ${i + 1} has a different number of columns. Nothing was imported.',
        );
      }
      try {
        final p = cell(phone);
        final number = p.isEmpty ? null : kenyaPhone(p);
        if (p.isNotEmpty && number == null) throw const FormatException();
        final customer = cell(name).isEmpty ? (number ?? '') : cell(name);
        final identity = identityFor(customer, number);
        var d = cell(date);
        if (RegExp(r'^(?:\d{2}/\d{2}/\d{4}|\d{4}-\d{2}-\d{2})$').hasMatch(d)) {
          d = '$d 00:00:00';
        }
        final at = parseStatementDate(d, row: i + 1);
        final cents = parseMoney(cell(amount), row: i + 1);
        if (cents <= 0) throw const FormatException();
        final stable = sale >= 0 && cell(sale).isNotEmpty
            ? 'sale:${cell(sale)}'
            : 'row:${sha256.convert(utf8.encode('$identity|${at.toIso8601String()}|$cents'))}';
        payments.add(
          CustomerPayment(
            id: stable,
            identity: identity,
            name: customer,
            phone: number,
            at: at,
            amount: cents,
          ),
        );
      } catch (_) {
        throw FormatException(
          'Sales row ${i + 1} has an invalid date, positive KES amount, customer or full Kenyan phone number. Nothing was imported.',
        );
      }
    }
    return payments;
  }
}
