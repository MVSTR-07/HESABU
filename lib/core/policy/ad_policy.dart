/// HESABU's base product is intentionally ad-free.
///
/// Keep this policy as a source-level boundary: no screen may embed an ad
/// provider, request advertising identifiers, or add an ad network endpoint.
/// A future commercial fork must make an explicit product and privacy change;
/// there is no runtime switch that silently enables third-party ads.
class AdPolicy {
  const AdPolicy._();

  static const enabled = false;
  static const provider = 'none';

  static bool allowProvider(String value) => false;
}
