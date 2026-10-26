import 'package:flutter/material.dart';
import 'app_controller.dart';
import 'features/auth/account_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/onboarding/intro_page.dart';
import 'features/settings/settings_page.dart';
import 'ui/theme.dart';

class BizLensApp extends StatelessWidget {
  const BizLensApp({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: 'BizLens',
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
              'Local storage is locked because deletion did not finish. Close and restart BizLens. No business data was sent.',
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
    };
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights, size: 28),
            SizedBox(width: 10),
            Flexible(child: Text('BizLens', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          if (controller.signedIn)
            IconButton(
              tooltip: 'Dashboard',
              icon: const Icon(Icons.dashboard_outlined),
              onPressed: controller.busy
                  ? null
                  : () => controller.navigate(AppPage.dashboard),
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
      body: AbsorbPointer(absorbing: controller.busy, child: content),
      bottomNavigationBar: controller.signedIn
          ? NavigationBar(
              selectedIndex: controller.page == AppPage.settings ? 1 : 0,
              onDestinationSelected: controller.busy
                  ? null
                  : (i) => controller.navigate(
                      i == 0 ? AppPage.dashboard : AppPage.settings,
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
            )
          : null,
    );
  }
}
