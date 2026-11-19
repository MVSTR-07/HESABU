/// Subscription state is deliberately separate from business data. A future
/// provider adapter may verify Google Play purchases or another billing
/// provider, but it must return entitlement metadata only.
abstract interface class EntitlementService {
  Future<Entitlement> refresh();
}

class Entitlement {
  const Entitlement({required this.plan, this.expiresAt});
  final Plan plan;
  final DateTime? expiresAt;

  bool get isPremium => plan == Plan.premium;
}

enum Plan { free, premium }

/// Current local provider for development. It is not billing or access
/// security; production must replace it with verified Play/App Store state.
class DemoEntitlementService implements EntitlementService {
  DemoEntitlementService(this.read);
  final String? Function(String key) read;

  @override
  Future<Entitlement> refresh() async =>
      Entitlement(plan: read('demo_paid') == 'true' ? Plan.premium : Plan.free);
}
