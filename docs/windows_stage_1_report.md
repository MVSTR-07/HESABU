# Windows and encrypted-storage verification

Windows desktop support was built with Flutter and Visual Studio's **Desktop
development with C++** workload. The Stage 1 checks covered the Windows toolchain,
SQLCipher, protected key storage, persistence across a full close/reopen, demo
account behavior and the local deletion controls. The project owner later signed
off Stages 1 through 3.

The Windows secure-storage integration check uses a disposable fabricated probe.
It verifies that the operating-system protected key can reopen an encrypted
database after the test process exits. It does not print or export the key. The
normal app was also reopened against its existing local workspace.

The sign-up and subscription screens are local demo stubs. No password is
requested or saved, and no account or billing service is connected. The code
marks real authentication and subscription checks as future work.

For current commands and status, see [validation](validation.md) and the
[Stage 4 manual checklist](stage_4_manual_test.md). Android device validation
has not been completed.
