import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/stock/stock_analysis.dart';
import '../../data/operations_repository.dart';
import '../operations/operations_widgets.dart';

class StockPage extends StatefulWidget {
  const StockPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  late final OperationsRepository _repository;
  List<StockItem> _items = [];

  @override
  void initState() {
    super.initState();
    _repository = OperationsRepository(widget.controller.store);
    _refresh();
  }

  void _refresh() => setState(() => _items = _repository.stock());

  Future<void> _editItem([StockItem? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final sku = TextEditingController(text: existing?.sku ?? '');
    final unit = TextEditingController(text: existing?.unit ?? 'units');
    final opening = TextEditingController(
      text: existing?.openingQuantity.toString() ?? '',
    );
    final received = TextEditingController(
      text: existing?.receivedQuantity.toString() ?? '',
    );
    final sold = TextEditingController(
      text: existing?.soldQuantity.toString() ?? '',
    );
    final damaged = TextEditingController(
      text: existing?.damagedQuantity.toString() ?? '',
    );
    final cost = TextEditingController(
      text: existing == null
          ? ''
          : (existing.unitCostMinor / 100).toStringAsFixed(2),
    );
    final reorder = TextEditingController(
      text: existing?.reorderLevel.toString() ?? '0',
    );
    var error = '';
    final item = await showDialog<StockItem>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: Text(
            existing == null ? 'Add a stock item' : 'Edit stock item',
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Item name'),
                  ),
                  TextField(
                    controller: sku,
                    decoration: const InputDecoration(
                      labelText: 'SKU / code (optional)',
                    ),
                  ),
                  TextField(
                    controller: unit,
                    decoration: const InputDecoration(
                      labelText: 'Unit (e.g. pieces, kg)',
                    ),
                  ),
                  TextField(
                    controller: opening,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Opening stock quantity',
                    ),
                  ),
                  TextField(
                    controller: received,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Units received since opening',
                    ),
                  ),
                  TextField(
                    controller: sold,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Units sold'),
                  ),
                  TextField(
                    controller: damaged,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Units damaged / written off',
                    ),
                  ),
                  TextField(
                    controller: cost,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Cost per unit (KES)',
                    ),
                  ),
                  TextField(
                    controller: reorder,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Reorder when stock reaches',
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
                final openQty = parseWholeNumber(opening.text, allowZero: true);
                final receivedQty = parseWholeNumber(
                  received.text,
                  allowZero: true,
                );
                final soldQty = parseWholeNumber(sold.text, allowZero: true);
                final damagedQty = parseWholeNumber(
                  damaged.text,
                  allowZero: true,
                );
                final unitCost = parseKesAmount(cost.text);
                final reorderQty = parseWholeNumber(
                  reorder.text,
                  allowZero: true,
                );
                if (name.text.trim().isEmpty || unit.text.trim().isEmpty) {
                  updateDialog(() => error = 'Enter an item name and unit.');
                  return;
                }
                if ([
                  openQty,
                  receivedQty,
                  soldQty,
                  damagedQty,
                  unitCost,
                  reorderQty,
                ].any((value) => value == null)) {
                  updateDialog(
                    () =>
                        error = 'Enter valid non-negative quantities and cost.',
                  );
                  return;
                }
                if (soldQty! + damagedQty! > openQty! + receivedQty!) {
                  updateDialog(
                    () => error =
                        'Sold and damaged units exceed available stock.',
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  StockItem(
                    id: existing?.id ?? operationId('STOCK'),
                    name: name.text.trim(),
                    sku: sku.text.trim(),
                    unit: unit.text.trim(),
                    openingQuantity: openQty,
                    receivedQuantity: receivedQty,
                    soldQuantity: soldQty,
                    damagedQuantity: damagedQty,
                    unitCostMinor: unitCost!,
                    reorderLevel: reorderQty!,
                    updatedAt: DateTime.now().toUtc(),
                  ),
                );
              },
              child: Text(existing == null ? 'Save item' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
    for (final controller in [
      name,
      sku,
      unit,
      opening,
      received,
      sold,
      damaged,
      cost,
      reorder,
    ]) {
      controller.dispose();
    }
    if (item == null || !mounted) return;
    try {
      _repository.saveStockItem(item);
      _refresh();
    } on FormatException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Stock item could not be saved to encrypted local storage.');
    }
  }

  Future<void> _deleteItem(StockItem item) async {
    if (!await confirmOperationDelete(context, item.name) || !mounted) return;
    _repository.deleteStockItem(item.id);
    _refresh();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final result = _repository.analyseStock();
    return OperationsPageFrame(
      title: 'Stock analyser',
      subtitle: 'Track stock levels, movement, stock value and reorder needs.',
      actions: [
        FilledButton.icon(
          onPressed: widget.controller.busy ? null : _editItem,
          icon: const Icon(Icons.add),
          label: const Text('Add stock item'),
        ),
        OutlinedButton.icon(
          onPressed: widget.controller.busy
              ? null
              : () {
                  _repository.addStockSamples();
                  _refresh();
                  _showMessage('Fabricated stock added on this device.');
                },
          icon: const Icon(Icons.science_outlined),
          label: const Text('Use fabricated stock'),
        ),
      ],
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OperationMetric('Stock items', '${result.itemCount}'),
            OperationMetric('Units on hand', '${result.unitsOnHand}'),
            OperationMetric(
              'Stock value at cost',
              moneyLabel(result.valueMinor),
            ),
            OperationMetric('Reorder needed', '${result.lowStock.length}'),
            OperationMetric('Out of stock', '${result.outOfStock.length}'),
          ],
        ),
        const SizedBox(height: 16),
        OperationsSection(
          title: 'Reorder alerts',
          child: result.lowStock.isEmpty
              ? const OperationEmpty(
                  'No items are at or below their reorder level.',
                )
              : Column(
                  children: [
                    for (final item in result.lowStock)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          item.quantityOnHand == 0
                              ? Icons.remove_shopping_cart_outlined
                              : Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(item.name),
                        subtitle: Text(
                          'On hand ${item.quantityOnHand} ${item.unit} · reorder at ${item.reorderLevel}',
                        ),
                        trailing: Text(moneyLabel(item.stockValueMinor)),
                      ),
                  ],
                ),
        ),
        OperationsSection(
          title: 'Fastest-moving items · units sold',
          child: result.fastMovers.isEmpty
              ? const OperationEmpty(
                  'Recorded stock movement will appear here.',
                )
              : Column(
                  children: [
                    for (final item in result.fastMovers.take(10))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.name),
                        trailing: Text('${item.soldQuantity} ${item.unit}'),
                      ),
                  ],
                ),
        ),
        OperationsSection(
          title: 'Inventory records',
          child: _items.isEmpty
              ? const OperationEmpty(
                  'No stock items yet. Add an item or use fabricated stock to preview the analysis.',
                )
              : LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth < 640
                      ? Column(
                          children: [
                            for (final item in _items)
                              _StockItemCard(
                                item: item,
                                onEdit: () => _editItem(item),
                                onDelete: () => _deleteItem(item),
                              ),
                          ],
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Item')),
                              DataColumn(label: Text('On hand')),
                              DataColumn(label: Text('Sold')),
                              DataColumn(label: Text('Value at cost')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('')),
                            ],
                            rows: [
                              for (final item in _items)
                                DataRow(
                                  cells: [
                                    DataCell(Text(item.name)),
                                    DataCell(
                                      Text(
                                        '${item.quantityOnHand} ${item.unit}',
                                      ),
                                    ),
                                    DataCell(Text('${item.soldQuantity}')),
                                    DataCell(
                                      Text(moneyLabel(item.stockValueMinor)),
                                    ),
                                    DataCell(
                                      Text(
                                        item.quantityOnHand <= item.reorderLevel
                                            ? 'Reorder'
                                            : 'In stock',
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Edit item',
                                            onPressed: () => _editItem(item),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete item',
                                            onPressed: () => _deleteItem(item),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                ),
        ),
      ],
    );
  }
}

class _StockItemCard extends StatelessWidget {
  const _StockItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });
  final StockItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(item.name),
    subtitle: Text(
      '${item.quantityOnHand} ${item.unit} · ${item.soldQuantity} sold · ${moneyLabel(item.stockValueMinor)} at cost · ${item.quantityOnHand <= item.reorderLevel ? 'Reorder' : 'In stock'}',
    ),
    trailing: PopupMenuButton<String>(
      tooltip: 'Stock item actions',
      onSelected: (action) => action == 'edit' ? onEdit() : onDelete(),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    ),
  );
}
