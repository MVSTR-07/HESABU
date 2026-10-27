import 'dart:convert';
import 'dart:typed_data';

import '../core/customers/customer_analysis.dart';
import '../core/customers/sales_parser.dart';
import '../core/mpesa/models.dart';
import 'local_store.dart';

/// Typed workspace in existing SQLCipher settings storage. No plaintext sidecar
/// or redundant report cache. Results are recomputed locally when reopened.
class CustomerRepository {
  CustomerRepository(this.store) {
    final raw = store.readSetting('customer_workspace');
    final data = raw == null
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    sales = (data['sales'] as List? ?? [])
        .map(
          (v) => CustomerPayment.fromJson(Map<String, dynamic>.from(v as Map)),
        )
        .toList();
    aliases = Map<String, String>.from(data['aliases'] as Map? ?? {});
    history = (data['history'] as List? ?? [])
        .map((v) => Map<String, String>.from(v as Map))
        .toList();
  }
  final LocalStore store;

  /// Settings must remain available even if a saved workspace is unreadable.
  CustomerRepository.settings(this.store) {
    sales = [];
    aliases = {};
    history = [];
  }
  late List<CustomerPayment> sales;
  late Map<String, String> aliases;
  late List<Map<String, String>> history;
  void _save() => store.writeSetting(
    'customer_workspace',
    jsonEncode({
      'sales': sales.map((v) => v.toJson()).toList(),
      'aliases': aliases,
      'history': history,
    }),
  );
  DropOffConfig get config => DropOffConfig(
    atRisk: double.tryParse(store.readSetting('customer_at_risk') ?? '') ?? 1.5,
    lost: double.tryParse(store.readSetting('customer_lost') ?? '') ?? 3,
  );
  String get template =>
      store.readSetting('customer_message_template') ??
      'Hello {name}, we would be happy to serve you again. Thank you for your support.';
  void saveConfig(DropOffConfig value, String message) {
    value.validate();
    store.writeSetting('customer_at_risk', value.atRisk.toString());
    store.writeSetting('customer_lost', value.lost.toString());
    store.writeSetting('customer_message_template', message);
  }

  void importSales(Uint8List bytes) {
    final incoming = const CustomerSalesParser().parse(bytes);
    final merged = {for (final p in sales) p.id: p};
    for (final p in incoming) {
      final old = merged[p.id];
      if (old != null &&
          (old.identity != p.identity ||
              old.amount != p.amount ||
              old.at != p.at)) {
        throw const FormatException(
          'A Sale ID has conflicting data. Use unique Sale IDs; nothing was imported.',
        );
      }
      merged.putIfAbsent(p.id, () => p);
    }
    if (merged.length > 50000) {
      throw const FormatException(
        'Saved sales exceed 50,000 rows. Use a shorter date range.',
      );
    }
    sales = merged.values.toList();
    _save();
  }

  void addSamples(DateTime asOf) {
    final all = {for (final p in sales) p.id: p};
    for (final p in generateCustomerSamples(asOf)) {
      all[p.id] = p;
    }
    sales = all.values.toList();
    _save();
  }

  List<CustomerPayment> payments() {
    final result = [...sales];
    final seen = <String>{};
    for (final summary in store.listMpesaStatements()) {
      final statement = store.loadMpesaStatement(summary.id);
      if (statement == null) continue;
      for (final t in statement.transactions) {
        if (t.type != MpesaType.customerPayment ||
            t.paidIn <= 0 ||
            !seen.add(t.fingerprint)) {
          continue;
        }
        var party = t.counterparty?.trim() ?? '';
        if (party.isEmpty) continue;
        final phoneMatch = RegExp(r'(?:\+?254|0)[17]\d{8}\b').firstMatch(party);
        final phone = phoneMatch == null
            ? null
            : kenyaPhone(phoneMatch.group(0)!);
        party = party
            .replaceAll(RegExp(r'(?:\+?254|0)[\d*]{6,}'), '')
            .replaceAll(RegExp(r'^\s*[-:]\s*|\s*[-:]\s*$'), '')
            .trim();
        final name = party.isEmpty ? (phone ?? '') : party;
        if (name.isEmpty) continue;
        result.add(
          CustomerPayment(
            id: 'mpesa:${t.fingerprint}',
            identity: identityFor(name, phone),
            name: name,
            phone: phone,
            at: t.at,
            amount: t.paidIn,
          ),
        );
      }
    }
    return result;
  }

  CustomerResults analyse(DateTime asOf) => const CustomerAnalyser().analyse(
    payments(),
    asOf: asOf,
    config: config,
    aliases: aliases,
  );
  void merge(String source, String target) {
    source = resolveCustomer(source, aliases);
    target = resolveCustomer(target, aliases);
    if (source == target) {
      throw const FormatException('Choose two different customers.');
    }
    final existing = payments()
        .map((p) => resolveCustomer(p.identity, aliases))
        .toSet();
    if (!existing.contains(source) || !existing.contains(target)) {
      throw const FormatException('Both customers must exist.');
    }
    history.add(Map.of(aliases));
    if (history.length > 20) history.removeAt(0);
    aliases[source] = target;
    _save();
  }

  void undoMerge() {
    if (history.isEmpty) return;
    aliases = history.removeLast();
    _save();
  }
}
