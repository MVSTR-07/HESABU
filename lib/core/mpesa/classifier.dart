import 'models.dart';
import 'statement_parser.dart' show parseMoney;

class MpesaClassifier {
  const MpesaClassifier();
  MpesaTransaction classify(MpesaTransaction tx) {
    final s = tx.details.toLowerCase();
    final compact = s.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (compact.contains('reversal') || compact.contains('reversed')) {
      return tx.classified(MpesaType.reversal);
    }
    if (compact.contains('fuliza') || compact.contains('overdraft')) {
      final role =
          RegExp(r'fee|charge|interest|maintenance|access cost').hasMatch(s) &&
              !RegExp(r'repay|recover|settle').hasMatch(s)
          ? FulizaRole.cost
          : RegExp(r'repay|recover|settle').hasMatch(s)
          ? FulizaRole.repayment
          : tx.paidIn > 0
          ? FulizaRole.draw
          : FulizaRole.unknown;
      var cost = role == FulizaRole.cost ? tx.withdrawn : 0;
      if (role == FulizaRole.repayment) {
        // Only explicit fee components count as cost, never loan principal.
        final match = RegExp(
          r'(?:fee|interest|charge)s?\s*(?:of|:)?\s*(?:kes|kshs?\.?\s*)?\s*([\d,]+\.\d{2}|\d+)',
        ).firstMatch(s);
        if (match != null) cost = parseMoney(match.group(1)!, row: tx.row);
        if (cost > tx.withdrawn) cost = 0; // Do not invent inconsistent fees.
      }
      return tx.classified(MpesaType.fuliza, role: role, cost: cost);
    }
    if (RegExp(r'fee|charge|excise duty').hasMatch(s)) {
      return tx.classified(MpesaType.fee);
    }
    final party = _party(tx.details);
    if (compact.contains('airtime')) return tx.classified(MpesaType.airtime);
    if (RegExp(
      r'paybill|till|buygoods|merchantpayment|paymerchant|businesspayment',
    ).hasMatch(compact)) {
      if (tx.paidIn > 0 && RegExp(r'received|from').hasMatch(s)) {
        return tx.classified(MpesaType.customerPayment, party: party);
      }
      return tx.classified(MpesaType.paybillTill, party: party);
    }
    if (RegExp(r'withdraw|cashout').hasMatch(compact)) {
      return tx.classified(MpesaType.withdrawal, party: party);
    }
    if (tx.paidIn > 0 &&
        RegExp(
          r'customerpayment|customertransferfrom|moneyreceived|fundsreceived|receivemoney|paymentreceived',
        ).hasMatch(compact)) {
      return tx.classified(MpesaType.customerPayment, party: party);
    }
    if (tx.withdrawn > 0 &&
        RegExp(r'customertransfer|sendmoney|moneysent|sentmoney|transferto')
            .hasMatch(compact)) {
      return tx.classified(MpesaType.sentMoney, party: party);
    }
    return tx.classified(MpesaType.unknown, party: party);
  }

  String? _party(String details) {
    final match = RegExp(
      r'\b(?:from|to|at)\s+(.+)',
      caseSensitive: false,
    ).firstMatch(details);
    if (match == null) return null;
    final value = match
        .group(1)!
        .split(RegExp(r'\s+(?:via|account|a/c|on)\s+', caseSensitive: false))
        .first
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return value.isEmpty ? null : value;
  }
}
