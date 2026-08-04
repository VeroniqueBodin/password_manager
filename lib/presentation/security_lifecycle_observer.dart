import 'package:flutter/widgets.dart';
import '../application/vault_service.dart';

class SecurityLifecycleObserver extends WidgetsBindingObserver {
  final VaultService _vaultService;

  SecurityLifecycleObserver(this._vaultService);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _vaultService.lockVault();
    }
  }
}