import 'package:flutter/material.dart';

/// Loads a deferred library before building its page.
///
/// On web, `import '…' deferred as x` puts the library into a separate
/// JavaScript part that is downloaded only when `x.loadLibrary()` runs, so
/// rarely used areas (the admin back office) stay out of the startup bundle.
/// On mobile the load completes immediately.
class DeferredPage extends StatefulWidget {
  const DeferredPage({
    super.key,
    required this.libraryKey,
    required this.load,
    required this.builder,
  });

  /// Stable identifier of the deferred library, used to skip the loading
  /// state once that library has been loaded in this session.
  final String libraryKey;
  final Future<void> Function() load;
  final WidgetBuilder builder;

  static final Set<String> _loaded = <String>{};

  @override
  State<DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<DeferredPage> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = _start();
  }

  Future<void> _start() async {
    if (DeferredPage._loaded.contains(widget.libraryKey)) return;
    await widget.load();
    DeferredPage._loaded.add(widget.libraryKey);
  }

  void _retry() => setState(() => _future = _start());

  @override
  Widget build(BuildContext context) {
    if (DeferredPage._loaded.contains(widget.libraryKey)) {
      return widget.builder(context);
    }
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return widget.builder(context);
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Не удалось загрузить раздел. Проверьте подключение.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _retry, child: const Text('Повторить')),
                  ],
                ),
              ),
            ),
          );
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
