import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import '../core/mpesa/models.dart';
import 'mpesa_import_service.dart';

class SelectedStatement {
  const SelectedStatement(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

class LocalStatementPicker {
  const LocalStatementPicker();
  Future<SelectedStatement?> pick() async {
    if (Platform.isAndroid) {
      // Do not call file_selector on Android: it makes a plaintext cache copy.
      final result = await const MethodChannel('hesabu/local_statement_picker')
          .invokeMapMethod<String, dynamic>('open');
      if (result == null) return null;
      return SelectedStatement(
        result['name'] as String,
        result['bytes'] as Uint8List,
      );
    }
    if (!Platform.isWindows) {
      throw const StatementImportException(
        'Statement import currently supports Windows and Android.',
      );
    }
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Financial statements (M-Pesa currently supported)',
          extensions: ['pdf', 'csv'],
        ),
      ],
    );
    if (file == null) return null;
    if (await file.length() > MpesaImportService.maxBytes) {
      throw const StatementImportException(
        'File exceeds 25 MB. Import a shorter statement.',
      );
    }
    final output = BytesBuilder(copy: false);
    await for (final chunk in file.openRead()) {
      if (output.length + chunk.length > MpesaImportService.maxBytes) {
        throw const StatementImportException(
          'File exceeds 25 MB. Import a shorter statement.',
        );
      }
      output.add(chunk);
    }
    return SelectedStatement(file.name, output.takeBytes());
  }
}
