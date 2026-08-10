import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import 'application/vault_service.dart';
import 'infrastructure/argon2_key_derivation.dart';
import 'infrastructure/connectivity_network_checker.dart';
import 'infrastructure/secure_storage_secret_repository.dart';
import 'infrastructure/sqlcipher_password_repository.dart';
import 'infrastructure/webdav_vault_synchronizer.dart';
import 'presentation/login_screen.dart';
import 'presentation/security_lifecycle_observer.dart';
import 'domain/i_store_local_secrets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  }

  const secureStorage = FlutterSecureStorage();
  final secretRepository = SecureStorageSecretRepository(secureStorage);

  final httpClient = http.Client();
  const pCloudWebDavUrl = 'https://ewebdav.pcloud.com';

  final synchronizer = WebDavVaultSynchronizer(
    secretRepository,
    pCloudWebDavUrl,
    httpClient,
  );

  final passwordRepository = SqlCipherPasswordRepository();
  final keyDerivation = Argon2KeyDerivation();

  final vaultService = VaultService(
    keyDerivation,
    passwordRepository,
    synchronizer,
    secretRepository,
  );

  final connectivity = Connectivity();
  final networkChecker = ConnectivityNetworkChecker(connectivity);

  runApp(PasswordManagerApp(
    vaultService: vaultService,
    networkChecker: networkChecker,
    secretRepository: secretRepository,
  ));
}

class PasswordManagerApp extends StatefulWidget {
  final VaultService vaultService;
  final ConnectivityNetworkChecker networkChecker;
  final IStoreLocalSecrets secretRepository;

  const PasswordManagerApp({
    Key? key,
    required this.vaultService,
    required this.networkChecker,
    required this.secretRepository,
  }) : super(key: key);

  @override
  State<PasswordManagerApp> createState() => _PasswordManagerAppState();
}

class _PasswordManagerAppState extends State<PasswordManagerApp> {
  late SecurityLifecycleObserver _observer;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _observer = SecurityLifecycleObserver(
      widget.vaultService,
      onLock: () {
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => LoginScreen(
              vaultService: widget.vaultService,
              networkChecker: widget.networkChecker,
              secretRepository: widget.secretRepository,
            ),
          ),
              (route) => false,
        );
      },
    );
    WidgetsBinding.instance.addObserver(_observer);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_observer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Gestionnaire MDP',
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
      ),
      home: LoginScreen(
        vaultService: widget.vaultService,
        networkChecker: widget.networkChecker,
        secretRepository: widget.secretRepository,
      ),
    );
  }
}