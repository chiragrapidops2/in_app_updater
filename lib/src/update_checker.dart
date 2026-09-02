import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'native_update_service.dart';

/// Builds the iOS update dialog; [onUpdate] opens the App Store, [onLater] dismisses.
typedef IosUpdateDialogBuilder = Widget Function(
    BuildContext context,
    UpdateCheckResult result,
    VoidCallback onUpdate,
    VoidCallback onLater,
    );

/// Builds the Android "restart to install" [SnackBar]; [onRestart] completes the update.
typedef AndroidRestartSnackBarBuilder = SnackBar Function(
    BuildContext context,
    VoidCallback onRestart,
    );

/// Wraps your home screen to show Groww-style update prompts: Play Core's
/// immediate/flexible flow on Android, an App Store dialog on iOS. Pass
/// [iosUpdateDialogBuilder]/[androidRestartSnackBarBuilder] to replace the
/// default UI, or leave unset to use the built-in dialog/snackbar.
class UpdateChecker extends StatefulWidget {
  const UpdateChecker({
    super.key,
    required this.child,
    this.iosUpdateDialogBuilder,
    this.androidRestartSnackBarBuilder,
  });

  final Widget child;
  final IosUpdateDialogBuilder? iosUpdateDialogBuilder;
  final AndroidRestartSnackBarBuilder? androidRestartSnackBarBuilder;

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
    void onRestart() => _updateService.completeFlexibleUpdate();
    final snackBar = widget.androidRestartSnackBarBuilder?.call(context, onRestart) ??
        SnackBar(
          duration: const Duration(days: 1),
          content: const Text('An update just downloaded.'),
          action: SnackBarAction(label: 'RESTART', onPressed: onRestart),
        );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _showIosUpdateDialog(UpdateCheckResult result) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        void onUpdate() {
          Navigator.of(dialogContext).pop();
          _updateService.openStore();
        }

        void onLater() => Navigator.of(dialogContext).pop();

        final builder = widget.iosUpdateDialogBuilder;
        if (builder != null) {
          return builder(dialogContext, result, onUpdate, onLater);
        }

        return AlertDialog(
          title: const Text('Update available'),
          content: Text(
            'A new version (${result.latestVersion}) is available. '
                'You are on ${result.currentVersion}.',
          ),
          actions: [
            TextButton(onPressed: onLater, child: const Text('Later')),
            FilledButton(onPressed: onUpdate, child: const Text('Update')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
