# Google Play security checklist

Before production publishing I will:

- replace the local demo provider with verified production authentication;
- keep passwords and provider tokens out of the encrypted business database;
- verify Google Play purchases on a trusted entitlement service;
- store only account identity, subscription state and billing identifiers on the
  account service;
- keep all statements, transactions, customers and results on-device;
- provide in-app and public-web account deletion;
- publish the privacy policy at a stable HTTPS URL;
- complete the Play Data Safety form to match the privacy policy and SDKs;
- test internal and closed releases on real Android devices before production.

Firebase/Google configuration files, signing keys and Play purchase tokens must
never be committed to this repository.
