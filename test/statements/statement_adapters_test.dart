import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hesabu/core/mpesa/models.dart';
import 'package:hesabu/core/statements/equity_adapter.dart';
import 'package:hesabu/core/statements/statement_adapter_registry.dart';
import 'package:hesabu/core/statements/statement_provider.dart';

void main() {
  test('registry exposes one explicit adapter per provider', () {
    const registry = StatementAdapterRegistry();
    for (final provider in StatementProvider.values) {
      expect(registry.adapterFor(provider).provider, provider);
    }
  });

  test('Equity adapter parses a normalized CSV row', () {
    const csv =
        'Date,Particulars,Money Out,Money In,Balance,Ref Number\n'
        '31/10/2026,Opening credit,,1250.00,1250.00,EQ123456';
    final parsed = const EquityStatementAdapter().parseCsv(
      Uint8List.fromList(csv.codeUnits),
    );
    expect(parsed.transactions, hasLength(1));
    expect(parsed.transactions.single.paidIn, 125000);
    expect(parsed.transactions.single.withdrawn, 0);
  });

  test('Equity empty statement returns a safe user error', () {
    expect(
      () => const EquityStatementAdapter().parsePdfText(
        'STATEMENT OF ACCOUNT\nNo transactions for this period',
      ),
      throwsA(isA<StatementImportException>()),
    );
  });
}
