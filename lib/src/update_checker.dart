import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'native_update_service.dart';

/// Wrap your home screen's content with this to get Groww-style update prompts:
/// Android uses Play Core's immediate (blocking) or flexible (background
/// download + "restart to install" snackbar) flow depending on update
/// priority; iOS shows a dialog linking out to the App Store, since Apple
/// has no in-app self-update mechanism.
class UpdateChecker extends StatefulWidget {
  const UpdateChecker({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  final _updateService = NativeUpdateService();
  StreamSubscription<Map<String, dynamic>>? _installStateSub;
  bool _flexibleUpdateInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  @override
  void dispose() {
    _installStateSub?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    final UpdateCheckResult result;
    try {
      result = await _updateService.checkForUpdate();
    } catch (_) {
      return; // e.g. no network, or not installed from a store build.
    }
    if (!result.updateAvailable || !mounted) return;

    if (Platform.isAndroid) {
      await _handleAndroidUpdate(result);
    } else if (Platform.isIOS) {
      await _showIosUpdateDialog(result);
    }
  }

  Future<void> _handleAndroidUpdate(UpdateCheckResult result) async {
    if (result.immediateAllowed) {
      // High-priority release: block the app until it's updated.
      await _updateService.startImmediateUpdate();
      return;
    }
    if (result.flexibleAllowed && !_flexibleUpdateInFlight) {
      _flexibleUpdateInFlight = true;
      _listenForFlexibleUpdate();
      await _updateService.startFlexibleUpdate();
    }
  }

  void _listenForFlexibleUpdate() {
    _installStateSub = _updateService.installStateStream().listen((event) {
      final status = _updateService.statusFromString(event['status'] as String?);
      if (status == InstallStatus.downloaded && mounted) {
        _showRestartSnackBar();
      }
    });
  }

  void _showRestartSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(days: 1),
        content: const Text('An update just downloaded.'),
        action: SnackBarAction(
          label: 'RESTART',
          onPressed: () => _updateService.completeFlexibleUpdate(),
        ),
      ),
    );
  }

  Future<void> _showIosUpdateDialog(UpdateCheckResult result) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update available'),
        content: Text(
          'A new version (${result.latestVersion}) is available. '
          'You are on ${result.currentVersion}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateService.openStore();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
