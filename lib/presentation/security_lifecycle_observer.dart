import 'package:flutter/widgets.dart';
import '../application/vault_service.dart';

class SecurityLifecycleObserver extends WidgetsBindingObserver {
  final VaultService _vaultService;
  final VoidCallback? onLock;

  SecurityLifecycleObserver(this._vaultService, {this.onLock});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_vaultService.isAuthenticatingBiometrically) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _vaultService.lockVault();
      if (onLock != null) {
        onLock!();
      }
    }
  }
}