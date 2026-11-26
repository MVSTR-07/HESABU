import 'statement_provider.dart';
import 'equity_adapter.dart';
import 'mpesa_adapter.dart';
import 'ncba_loop_adapter.dart';
import 'coop_yea_adapter.dart';

class StatementAdapterRegistry {
  const StatementAdapterRegistry();

  StatementAdapter adapterFor(StatementProvider provider) => switch (provider) {
    StatementProvider.equity => const EquityStatementAdapter(),
    StatementProvider.mpesa => const MpesaStatementAdapter(),
    StatementProvider.ncbaLoop => const NcbaLoopStatementAdapter(),
    StatementProvider.coopYea => const CoopYeaStatementAdapter(),
  };
}
