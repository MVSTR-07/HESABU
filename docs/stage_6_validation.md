# Stage 6 validation

Checked locally on 20/11/2026:

- `flutter analyze --no-pub` completed with no issues.
- `flutter test --no-pub --concurrency=1` completed successfully.
- Gateway tests confirm a consent token cannot be reused for a changed payload,
  that a mismatched request never reaches a provider adapter, and that matching
  consent is forwarded correctly.
- The Settings preview test confirms the dialog discloses fabricated content and
  that choosing **Keep data on this device** closes it without enabling AI.

The SQLCipher tests intentionally attempt a wrong key and may print a decryption
failure line while proving that encrypted storage rejects the key.
