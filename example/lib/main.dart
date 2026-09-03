import 'package:flutter/material.dart';
import 'package:in_app_updater/in_app_updater.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: UpdateChecker(child: HomePage()));
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _updateService = NativeUpdateService();
  String _lastResult = 'Tap the button to call the native update check.';

  Future<void> _checkForUpdate() async {
    try {
      final result = await _updateService.checkForUpdate();
      setState(() => _lastResult = _describe(result));
    } catch (e) {
      setState(() => _lastResult = 'checkForUpdate failed: $e');
    }
  }

  String _describe(UpdateCheckResult result) =>
      'updateAvailable: ${result.updateAvailable}\n'
      'immediateAllowed: ${result.immediateAllowed}\n'
      'flexibleAllowed: ${result.flexibleAllowed}\n'
      'currentVersion: ${result.currentVersion}\n'
      'latestVersion: ${result.latestVersion}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('in_app_updater example')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'UpdateChecker already ran once automatically on launch '
              '(see the Android snackbar / iOS dialog if a real update is live).\n'
              'Use this button to call the native side directly and see the raw result:',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkForUpdate,
              child: const Text('Check for update'),
            ),
            const SizedBox(height: 16),
            Text(_lastResult),
          ],
        ),
      ),
    );
  }
}
