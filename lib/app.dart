import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'features/auth/account_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/onboarding/intro_page.dart';
import 'features/settings/settings_page.dart';
import 'features/mpesa/mpesa_page.dart';
import 'features/customers/customers_page.dart';
import 'features/stock/stock_page.dart';
import 'features/sales/sales_page.dart';
import 'features/expenses/expenses_page.dart';
import 'features/finance/profit_page.dart';
import 'features/debts/debts_page.dart';
import 'features/imports/imports_page.dart';
import 'features/reports/reports_page.dart';
import 'features/workspaces/workspaces_page.dart';
import 'ui/theme.dart';
import 'ui/glass.dart';

class HesabuApp extends StatelessWidget {
  const HesabuApp({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: 'HESABU',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: controller.themeMode,
      home: _Workspace(controller: controller),
    ),
  );
}

class _Workspace extends StatelessWidget {
  const _Workspace({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.storageLocked) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Local storage is locked because deletion did not finish. Close and restart HESABU. No business data was sent.',
            ),
          ),
        ),
      );
    }
    final content = switch (controller.page) {
      AppPage.intro => IntroPage(controller: controller),
      AppPage.account => AccountPage(controller: controller),
      AppPage.dashboard => DashboardPage(controller: controller),
      AppPage.settings => SettingsPage(controller: controller),
      AppPage.mpesa => MpesaPage(controller: controller),
      AppPage.customers => CustomersPage(controller: controller),
      AppPage.stock => StockPage(controller: controller),
      AppPage.sales => SalesPage(controller: controller),
      AppPage.expenses => ExpensesPage(controller: controller),
      AppPage.profit => ProfitPage(controller: controller),
      AppPage.debts => DebtsPage(controller: controller),
      AppPage.imports => ImportsPage(controller: controller),
      AppPage.reports => ReportsPage(controller: controller),
      AppPage.workspaces => WorkspacesPage(controller: controller),
    };
    final floatingNavigation = controller.signedIn;
    final visibleNavigation =
        floatingNavigation &&
        (controller.page == AppPage.dashboard ||
            controller.page == AppPage.settings);
    return HesabuBackdrop(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 76,
          leading: _isToolPage(controller.page)
              ? IconButton(
                  tooltip: 'Back to dashboard',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: controller.busy
                      ? null
                      : () => controller.navigate(AppPage.dashboard),
                )
              : null,
          title: const HesabuBrand(compact: true),
          flexibleSpace: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: .06),
                ),
              ),
            ),
          ),
          actions: [
            // Tool pages already have a back arrow. Hiding the duplicate
            // dashboard action there keeps the app bar usable on narrow phones
            // and with large accessibility text.
            if (controller.signedIn && !_isToolPage(controller.page))
              IconButton(
                tooltip: 'Dashboard',
                icon: const Icon(Icons.dashboard_outlined),
                onPressed: controller.busy
                    ? null
                    : () => controller.navigate(AppPage.dashboard),
              ),
            if (controller.signedIn)
              IconButton(
                tooltip: 'Workspaces',
                icon: const Icon(Icons.business_center_outlined),
                onPressed: controller.busy
                    ? null
                    : () => controller.navigate(AppPage.workspaces),
              ),
            if (!controller.signedIn && controller.page != AppPage.intro)
              IconButton(
                tooltip: 'Introduction',
                icon: const Icon(Icons.home_outlined),
                onPressed: controller.busy
                    ? null
                    : () => controller.navigate(AppPage.intro),
              ),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: controller.busy
                  ? null
                  : () => controller.navigate(AppPage.settings),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: AbsorbPointer(absorbing: controller.busy, child: content),
            ),
            if (visibleNavigation)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: GlassPanel(
                          radius: 32,
                          fillOpacity: 0.34,
                          refractionStrength: 2.7,
                          grouped: false,
                          child: NavigationBar(
                            selectedIndex: controller.page == AppPage.settings
                                ? 1
                                : 0,
                            onDestinationSelected: controller.busy
                                ? null
                                : (i) => controller.navigate(
                                    i == 0
                                        ? AppPage.dashboard
                                        : AppPage.settings,
                                  ),
                            destinations: const [
                              NavigationDestination(
                                icon: Icon(Icons.grid_view_outlined),
                                selectedIcon: Icon(Icons.grid_view),
                                label: 'Dashboard',
                              ),
                              NavigationDestination(
                                icon: Icon(Icons.settings_outlined),
                                selectedIcon: Icon(Icons.settings),
                                label: 'Settings',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool _isToolPage(AppPage page) => switch (page) {
  AppPage.mpesa ||
  AppPage.customers ||
  AppPage.stock ||
  AppPage.sales ||
  AppPage.expenses ||
  AppPage.profit ||
  AppPage.debts ||
  AppPage.imports ||
  AppPage.reports => true,
  AppPage.intro ||
  AppPage.account ||
  AppPage.dashboard ||
  AppPage.workspaces ||
  AppPage.settings => false,
};
