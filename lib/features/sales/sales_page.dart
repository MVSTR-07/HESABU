import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/sales/sales_analysis.dart';
import '../../data/operations_repository.dart';
import '../../ui/formatters.dart';
import '../operations/operations_widgets.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  late final OperationsRepository _repository;
  List<SaleRecord> _sales = [];

  @override
  void initState() {
    super.initState();
    _repository = OperationsRepository(widget.controller.store);
    _refresh();
  }

  void _refresh() => setState(() => _sales = _repository.sales());

  Future<void> _addSale([SaleRecord? existing]) async {
    final product = TextEditingController(text: existing?.product ?? '');
    final quantity = TextEditingController(
      text: existing?.quantity.toString() ?? '',
    );
    final price = TextEditingController(
      text: existing == null
          ? ''
          : (existing.unitPriceMinor / 100).toStringAsFixed(2),
    );
    final customer = TextEditingController(text: existing?.customerName ?? '');
    var date = existing?.soldAt ?? DateTime.now().toUtc();
    var error = '';
    final sale = await showDialog<SaleRecord>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: Text(existing == null ? 'Add a sale' : 'Edit sale'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: product,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Product'),
                  ),
                  TextField(
                    controller: quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Unit price (KES)',
                    ),
                  ),
                  TextField(
                    controller: customer,
                    decoration: const InputDecoration(
                      labelText: 'Customer (optional)',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final picked = await pickOperationDate(context, date);
                        if (picked != null) updateDialog(() => date = picked);
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('Date · ${formatKenyaDate(date)}'),
                    ),
                  ),
                  if (error.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final qty = parseWholeNumber(quantity.text);
                final unitPrice = parseKesAmount(price.text);
                if (product.text.trim().isEmpty || qty == null) {
                  updateDialog(
                    () => error = 'Enter a product and a positive quantity.',
                  );
                  return;
                }
                if (unitPrice == null) {
                  updateDialog(
                    () => error = 'Enter a positive KES unit price.',
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  SaleRecord(
                    id: existing?.id ?? operationId('SALE'),
                    soldAt: date,
                    product: product.text.trim(),
                    quantity: qty,
                    unitPriceMinor: unitPrice,
                    customerName: customer.text.trim(),
                  ),
                );
              },
              child: Text(existing == null ? 'Save sale' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
    product.dispose();
    quantity.dispose();
    price.dispose();
    customer.dispose();
    if (sale == null || !mounted) return;
    try {
      _repository.saveSale(sale);
      _refresh();
    } on FormatException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Sale could not be saved to encrypted local storage.');
    }
  }

  Future<void> _deleteSale(SaleRecord sale) async {
    if (!await confirmOperationDelete(context, sale.product) || !mounted) {
      return;
    }
    _repository.deleteSale(sale.id);
    _refresh();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final result = _repository.analyseSales();
    return OperationsPageFrame(
      title: 'Sales analyser',
      subtitle: 'Track daily revenue, products sold and average sale value.',
      actions: [
        FilledButton.icon(
          onPressed: widget.controller.busy ? null : _addSale,
          icon: const Icon(Icons.add),
          label: const Text('Add sale'),
        ),
        OutlinedButton.icon(
          onPressed: widget.controller.busy
              ? null
              : () {
                  _repository.addSalesSamples();
                  _refresh();
                  _showMessage('Fabricated sales added on this device.');
                },
          icon: const Icon(Icons.science_outlined),
          label: const Text('Use fabricated sales'),
        ),
      ],
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OperationMetric('Sales revenue', moneyLabel(result.revenueMinor)),
            OperationMetric('Sales records', '${result.saleCount}'),
            OperationMetric('Units sold', '${result.unitsSold}'),
            OperationMetric(
              'Average per record',
              moneyLabel(result.averageSaleMinor),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OperationsSection(
          title: 'Daily sales · KES',
          child: result.days.isEmpty
              ? const OperationEmpty(
                  'No sales yet. Add a sale or use fabricated sales to preview the trend.',
                )
              : _DailySalesChart(days: result.days),
        ),
        OperationsSection(
          title: 'Top products by revenue',
          child: result.products.isEmpty
              ? const OperationEmpty('Product sales will appear here.')
              : Column(
                  children: [
                    for (final product in result.products.take(10))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(product.product),
                        subtitle: Text('${product.quantity} units sold'),
                        trailing: Text(moneyLabel(product.revenueMinor)),
                      ),
                  ],
                ),
        ),
        OperationsSection(
          title: 'Sales records',
          child: _sales.isEmpty
              ? const OperationEmpty('No saved sales records.')
              : Column(
                  children: [
                    for (final sale in _sales.take(100))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(sale.product),
                        subtitle: Text(
                          '${formatKenyaDate(sale.soldAt)} · ${sale.quantity} × ${moneyLabel(sale.unitPriceMinor)} · ${moneyLabel(sale.totalMinor)}${sale.customerName.isEmpty ? '' : ' · ${sale.customerName}'}',
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Sale actions',
                          onSelected: (action) => action == 'edit'
                              ? _addSale(sale)
                              : _deleteSale(sale),
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ),
                    if (_sales.length > 100)
                      const Text('Showing the latest 100 saved records.'),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DailySalesChart extends StatelessWidget {
  const _DailySalesChart({required this.days});
  final List<DailySales> days;

  @override
  Widget build(BuildContext context) {
    final visible = days.length <= 14 ? days : days.sublist(days.length - 14);
    final maximum = visible.fold<int>(
      0,
      (value, item) => value > item.revenueMinor ? value : item.revenueMinor,
    );
    return SizedBox(
      height: 156,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in visible)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message:
                          '${formatKenyaDate(day.day)} · ${moneyLabel(day.revenueMinor)}',
                      child: Container(
                        height: maximum == 0
                            ? 2
                            : 104 * day.revenueMinor / maximum,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${day.day.day}/${day.day.month}',
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
