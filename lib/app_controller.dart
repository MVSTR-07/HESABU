import 'package:flutter/material.dart';

import 'data/local_store.dart';
import 'data/workspace_repository.dart';
import 'data/account_security.dart';

enum AppPage {
  intro,
  account,
  dashboard,
  tools,
  settings,
  mpesa,
  customers,
  stock,
  sales,
  expenses,
  profit,
  debts,
  imports,
  reports,
  workspaces,
  statementImport,
}

/// Local-only demo identity and entitlement. No server, payment or password
/// handling exists in Stage 1. A future auth adapter must accept email only.
// TODO(real-auth): Replace this email-only DEMO STUB with verified authentication.
// Never collect or persist plaintext passwords. The account service may retain
// email and subscription status only; business data must stay on-device.
// TODO(real-subscription): Replace demo_paid with verified entitlement before
// production. This local switch is not billing or access security.
class AppController extends ChangeNotifier {
  AppController(this.store) {
    workspaces = WorkspaceRepository(store);
    email = store.readSetting('account_email');
    signedIn = store.readSetting('signed_in') == 'true' && email != null;
    paid = store.readSetting('demo_paid') == 'true';
    aiEnabled = store.readSetting('ai_enabled') == 'true';
    themeMode = switch (store.readSetting('theme')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      // Follow the device appearance by default; users can still choose a
      // fixed light or dark theme in Settings.
      _ => ThemeMode.system,
    };
    page = signedIn ? AppPage.dashboard : AppPage.intro;
  }
  final LocalStore store;
  static const _passwordKey = 'account_password_verifier_v1';
  static const _accountSecurity = AccountSecurity();
  late final WorkspaceRepository workspaces;
  late AppPage page;
  final List<AppPage> _history = [];
  late ThemeMode themeMode;
  String? email;
  bool signedIn = false;
  bool paid = false;

  /// A local preference only. It never configures a provider or permits sending.
  bool aiEnabled = false;
  bool busy = false;
  bool storageLocked = false;
  bool developerPreview = false;

  void enterDeveloperPreview() {
    developerPreview = true;
    signedIn = true;
    email = 'developer-preview@local';
    page = AppPage.dashboard;
    _history.clear();
    notifyListeners();
  }

  void navigate(AppPage next) {
    if (page == next) return;
    _history.add(page);
    page = next;
    notifyListeners();
  }

  bool get canGoBack => _history.isNotEmpty;

  /// Pops exactly one in-app page. The Android Home and Recents controls are
  /// handled by the operating system and never call this method.
  bool goBack() {
    if (_history.isEmpty) return false;
    page = _history.removeLast();
    notifyListeners();
    return true;
  }

  /// Rebuilds UI after a repository operation that already persisted locally.
  void refresh() => notifyListeners();

  /// Locks navigation during import, including the password prompt, so cleanup
  /// cannot race an unfinished import and allow it to save data after a wipe.
  void setImportBusy(bool value) {
    busy = value;
    notifyListeners();
  }

  String? enterDemo(String value, {required bool create}) {
    final normalized = value.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized)) {
      return 'Enter a valid email address.';
    }
    if (!create && email != normalized) {
      return 'No demo profile matches this email on this device. Use Sign up.';
    }
    if (create && email != null && email != normalized) {
      return 'This device already has a demo profile. Log in with that email, or delete all data in Settings.';
    }
    email = normalized;
    store.writeSetting('account_email', normalized);
    store.writeSetting('signed_in', 'true');
    signedIn = true;
    page = AppPage.dashboard;
    _history.clear();
    notifyListeners();
    return null;
  }

  void signOut() {
    store.writeSetting('signed_in', 'false');
    signedIn = false;
    developerPreview = false;
    page = AppPage.intro;
    _history.clear();
    notifyListeners();
  }

  void setTheme(ThemeMode value) {
    store.writeSetting('theme', value.name);
    themeMode = value;
    notifyListeners();
  }

  void setDemoPaid(bool value) {
    store.writeSetting('demo_paid', value.toString());
    paid = value;
    notifyListeners();
  }

  bool get hasAccountPassword =>
      (store.readSetting(_passwordKey) ?? '').isNotEmpty;

  String? setAccountPassword(String password) {
    try {
      store.writeSetting(
        _passwordKey,
        _accountSecurity.createVerifier(password),
      );
      notifyListeners();
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  bool verifyAccountPassword(String password) {
    final verifier = store.readSetting(_passwordKey);
    return verifier != null && _accountSecurity.verify(verifier, password);
  }

  void setAiEnabled(bool value) {
    store.writeSetting('ai_enabled', value.toString());
    aiEnabled = value;
    notifyListeners();
  }

  void seedSamples() {
    store.seedSamples();
    notifyListeners();
  }

  Future<void> clearCache() async {
    busy = true;
    notifyListeners();
    try {
      await store.clearCache();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> deleteAllData() async {
    busy = true;
    notifyListeners();
    try {
      await store.deleteAllData();
      email = null;
      signedIn = false;
      developerPreview = false;
      paid = false;
      aiEnabled = false;
      store.writeSetting(_passwordKey, '');
      themeMode = ThemeMode.system;
      page = AppPage.intro;
      _history.clear();
    } catch (_) {
      storageLocked = true;
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
