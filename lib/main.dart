import 'package:flutter/material.dart';

import 'app.dart';
import 'app_controller.dart';
import 'data/device_store.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Startup());
}

class _Startup extends StatefulWidget {
  const _Startup();
  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  AppController? _controller;
  bool _failed = false;
  bool _busy = true;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open({bool reset = false}) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final store = reset
          ? await DeviceStore.resetOnDevice()
          : await DeviceStore.open();
      if (!mounted) {
        store.close();
        return;
      }
      setState(() {
        _controller = AppController(store);
        _busy = false;
      });
    } catch (_) {
      // Never log exceptions: native messages can contain SQL or local paths.
      if (mounted) {
        setState(() {
          _failed = true;
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.store.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null) return HesabuApp(controller: _controller!);
    return MaterialApp(
      title: 'HESABU',
      theme: buildTheme(Brightness.dark),
      home: Scaffold(
        backgroundColor: const Color(0xff071329),
        body: SafeArea(
          child: Center(
            child: Builder(
              builder: (context) => Padding(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_busy) const CircularProgressIndicator(),
                      if (_failed) ...[
                        const Icon(Icons.lock_outline, size: 40),
                        const SizedBox(height: 16),
                        const Text(
                          'HESABU could not unlock encrypted local storage. Check free space and device secure-storage access, then retry. No data was sent and no unencrypted database was used.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => _open(),
                          child: const Text('Retry'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Erase locked local data?'),
                                content: const Text(
                                  'This permanently deletes all HESABU local data, its encryption key and cached files. Your original files outside HESABU are not touched. This cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Erase and start fresh'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && mounted) {
                              await _open(reset: true);
                            }
                          },
                          child: const Text('Delete all data / clear cache'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
