import 'package:flutter/material.dart';

import '../../app_controller.dart';

class ToolDefinition {
  const ToolDefinition(
    this.id,
    this.title,
    this.description,
    this.icon, {
    required this.stage,
    this.paid = false,
    this.page,
  });
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int stage;
  final bool paid;
  final AppPage? page;
}

// Add a card here once. The dashboard never hardcodes individual tools.
// Pricing is illustrative and explicitly labelled as a Stage 1 demo.
const tools = [
  ToolDefinition(
    'mpesa',
    'M-Pesa statements',
    'Understand where your money goes.',
    Icons.account_balance_wallet_outlined,
    stage: 2,
    page: AppPage.mpesa,
  ),
  ToolDefinition(
    'customers',
    'Customer performance',
    'Know your best clients. Spot drop-offs.',
    Icons.people_outline,
    stage: 3,
    paid: true,
    page: AppPage.customers,
  ),
  ToolDefinition(
    'stock',
    'Stock analyser',
    'See what moves and what stays.',
    Icons.inventory_2_outlined,
    stage: 4,
    paid: true,
  ),
  ToolDefinition(
    'sales',
    'Sales analyser',
    'Find patterns in your daily sales.',
    Icons.show_chart,
    stage: 4,
  ),
  ToolDefinition(
    'expenses',
    'Expense analyser',
    'Keep business costs in view.',
    Icons.receipt_long_outlined,
    stage: 4,
  ),
  ToolDefinition(
    'profit',
    'Profit & loss',
    'Turn your records into a clear picture.',
    Icons.pie_chart_outline,
    stage: 5,
    paid: true,
  ),
  ToolDefinition(
    'debts',
    'Debtors & creditors',
    'Track what is owed, in both directions.',
    Icons.swap_horiz,
    stage: 5,
    paid: true,
  ),
  ToolDefinition(
    'imports',
    'Import & clean',
    'Prepare Excel and CSV records.',
    Icons.upload_file_outlined,
    stage: 5,
  ),
  ToolDefinition(
    'reports',
    'Export reports',
    'Create PDF and Excel summaries.',
    Icons.file_download_outlined,
    stage: 5,
    paid: true,
  ),
];
