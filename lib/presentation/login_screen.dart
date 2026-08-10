import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../application/vault_service.dart';
import '../domain/i_check_network_connection.dart';
import '../domain/i_store_local_secrets.dart';
import 'initialization_screen.dart';
import 'vault_screen.dart';

class LoginScreen extends StatefulWidget {
  final VaultService vaultService;
  final ICheckNetworkConnection networkChecker;
  final IStoreLocalSecrets secretRepository;

  const LoginScreen({
    Key? key,
    required this.vaultService,
    required this.networkChecker,
    required this.secretRepository,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLoading = false;
  bool _canUseBiometrics = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedUsernameAndCheckBiometrics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSavedUsernameAndCheckBiometrics();
    }
  }

  Future<void> _loadSavedUsernameAndCheckBiometrics() async {
    final savedUsername = await widget.secretRepository.getLastUsername();
    if (savedUsername != null && mounted) {
      setState(() {
        _usernameController.text = savedUsername;
      });
    }

    final isSessionValid = await widget.vaultService.isBiometricSessionValid();
    final canCheckBiometrics = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();

    if (mounted) {
      setState(() {
        _canUseBiometrics = isSessionValid && (canCheckBiometrics || isDeviceSupported);
      });
    }
  }

  Future<void> _showWebDavConfigDialog() async {
    final emailController = TextEditingController();
    final pwdController = TextEditingController();

    final currentCreds = await widget.secretRepository.getWebDavCredentials();
    emailController.text = currentCreds['username'] ?? '';

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuration pCloud (WebDAV)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ces identifiants seront stockés dans le coffre natif de votre appareil.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email pCloud'),
            ),
            TextField(
              controller: pwdController,
              decoration: const InputDecoration(labelText: 'Mot de passe pCloud'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              await widget.secretRepository.saveWebDavCredentials(
                emailController.text.trim(),
                pwdController.text,
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Identifiants sauvegardés et chiffrés.')),
                );
              }
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  Future<void> _unlockWithPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rawUsername = _usernameController.text.trim().toLowerCase();
      final userHash = sha256.convert(utf8.encode(rawUsername)).toString();

      await widget.secretRepository.saveLastUsername(rawUsername);

      final isOnline = await widget.networkChecker.isConnected;

      await widget.vaultService.unlockVault(
        _passwordController.text,
        userHash,
        isOnline,
      );

      _passwordController.clear();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => VaultScreen(
              vaultService: widget.vaultService,
              isOfflineMode: !isOnline,
              userHash: userHash,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _unlockWithBiometrics() async {
    if (_usernameController.text.isEmpty) return;

    widget.vaultService.isAuthenticatingBiometrically = true;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Veuillez vous authentifier pour ouvrir le coffre',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      widget.vaultService.isAuthenticatingBiometrically = false;

      if (!authenticated) return;

      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final rawUsername = _usernameController.text.trim().toLowerCase();
      final userHash = sha256.convert(utf8.encode(rawUsername)).toString();

      await widget.vaultService.unlockVaultWithBiometrics(userHash);

      final isOnline = await widget.networkChecker.isConnected;

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => VaultScreen(
              vaultService: widget.vaultService,
              isOfflineMode: !isOnline,
              userHash: userHash,
            ),
          ),
        );
      }
    } on PlatformException catch (e) {
      widget.vaultService.isAuthenticatingBiometrically = false;
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur système : ${e.message}';
        });
      }
    } catch (e) {
      widget.vaultService.isAuthenticatingBiometrically = false;
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      widget.vaultService.isAuthenticatingBiometrically = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 80, color: Colors.blueGrey),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Identifiant',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    enabled: !_isLoading,
                    validator: (value) => value == null || value.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Mot de Passe Maître',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key),
                    ),
                    obscureText: true,
                    enabled: !_isLoading,
                    validator: (value) => value == null || value.isEmpty ? 'Requis' : null,
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 24),
                      color: Colors.red.shade100,
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _unlockWithPassword,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Déverrouiller le coffre', style: TextStyle(fontSize: 18)),
                  ),
                  if (_canUseBiometrics) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _unlockWithBiometrics,
                      icon: const Icon(Icons.fingerprint, size: 28),
                      label: const Text('Déverrouillage Rapide (Biométrie)', style: TextStyle(fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => InitializationScreen(
                            vaultService: widget.vaultService,
                          ),
                        ),
                      );
                    },
                    child: const Text('Créer un nouveau coffre'),
                  ),
                  TextButton.icon(
                    onPressed: _showWebDavConfigDialog,
                    icon: const Icon(Icons.cloud_sync, size: 18),
                    label: const Text('Configuration Serveur pCloud'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}