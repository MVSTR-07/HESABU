import 'package:bizlens/core/mpesa/classifier.dart';
import 'package:bizlens/core/mpesa/models.dart';
import 'package:flutter_test/flutter_test.dart';

MpesaTransaction fixtureTx(
  int row,
  int amount, {
  String details = 'Customer Payment from Wanjiku',
  bool outgoing = false,
  String? receipt,
}) => MpesaTransaction(
  row: row,
  at: DateTime.utc(2026, 1, row.clamp(1, 28), 7),
  receipt: receipt ?? 'QA26A${row.toString().padLeft(5, '0')}',
  details: details,
  paidIn: outgoing ? 0 : amount,
  withdrawn: outgoing ? amount : 0,
  balance: null,
);

void main() {
  const classifier = MpesaClassifier();
  final cases = <(String, bool, MpesaType)>[
    (
      'Customer Payment from 0700000001 - Wanjiku Mwangi',
      false,
      MpesaType.customerPayment,
    ),
    ('Funds received from Amina Hassan', false, MpesaType.customerPayment),
    ('Customer Transfer to Kamau Njoroge', true, MpesaType.sentMoney),
    ('Cash Withdrawal at Agent 999001', true, MpesaType.withdrawal),
    ('Airtime Purchase', true, MpesaType.airtime),
    ('Pay Bill to Kenya Power', true, MpesaType.paybillTill),
    ('Buy Goods Till payment to Ndovu', true, MpesaType.paybillTill),
    ('Pay Bill transaction charge', true, MpesaType.fee),
    ('Fuliza M-PESA disbursement', false, MpesaType.fuliza),
    ('Reversal of Fuliza fee', false, MpesaType.reversal),
    ('Cash deposit', false, MpesaType.unknown),
  ];
  for (final c in cases) {
    test(
      'classifies ${c.$1}',
      () => expect(
        classifier
            .classify(fixtureTx(1, 10000, details: c.$1, outgoing: c.$2))
            .type,
        c.$3,
      ),
    );
  }
  test('Fuliza principal is never treated as a financing cost', () {
    final principal = classifier.classify(
      fixtureTx(
        1,
        500000,
        details: 'Fuliza principal repayment',
        outgoing: true,
      ),
    );
    expect(principal.fulizaRole, FulizaRole.repayment);
    expect(principal.fulizaCost, 0);
    final fee = classifier.classify(
      fixtureTx(2, 5000, details: 'Fuliza access fee', outgoing: true),
    );
    expect(fee.fulizaCost, 5000);
    final bundled = classifier.classify(
      fixtureTx(
        3,
        505000,
        details: 'Fuliza repayment including fee KES 50.00',
        outgoing: true,
      ),
    );
    expect(bundled.fulizaCost, 5000);
  });
}
