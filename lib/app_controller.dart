import 'package:flutter/material.dart';

import 'data/local_store.dart';

enum AppPage { intro, account, dashboard, settings }

/// Local-only demo identity and entitlement. No server, payment or password
/// handling exists in Stage 1. A future auth adapter must accept email only.
class AppController extends ChangeNotifier {
  AppController(this.store) {
    email = store.readSetting('account_email');
    signedIn = store.readSetting('signed_in') == 'true' && email != null;
    paid = store.readSetting('demo_paid') == 'true';
    themeMode = switch (store.readSetting('theme')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    page = signedIn ? AppPage.dashboard : AppPage.intro;
  }
  final LocalStore store;
  late AppPage page;
  late ThemeMode themeMode;
  String? email;
  bool signedIn = false;
  bool paid = false;
  bool busy = false;
  bool storageLocked = false;

  void navigate(AppPage next) {
    page = next;
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
    notifyListeners();
    return null;
  }

  void signOut() {
    store.writeSetting('signed_in', 'false');
    signedIn = false;
    page = AppPage.intro;
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
      paid = false;
      themeMode = ThemeMode.system;
      page = AppPage.intro;
    } catch (_) {
      storageLocked = true;
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
