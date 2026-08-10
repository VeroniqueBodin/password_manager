import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../application/vault_service.dart';
import '../domain/vault_parameters.dart';

class InitializationScreen extends StatefulWidget {
  final VaultService vaultService;

  const InitializationScreen({
    Key? key,
    required this.vaultService,
  }) : super(key: key);

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _dicewareWords = [
    'cheval', 'batterie', 'agrafe', 'correct', 'maison',
    'soleil', 'guitare', 'nuage', 'oiseau', 'fleur',
    'montagne', 'riviere', 'fenetre', 'voiture', 'ordinateur'
  ];

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _generateDicewarePassword() {
    final random = Random.secure();
    final words = <String>[];
    for (int i = 0; i < 5; i++) {
      words.add(_dicewareWords[random.nextInt(_dicewareWords.length)]);
    }
    return words.join('-');
  }

  void _fillRandomPassword() {
    setState(() {
      _passwordController.text = _generateDicewarePassword();
    });
  }

  String _generateSecureSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  Future<void> _initializeVault() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rawUsername = _usernameController.text.trim().toLowerCase();
      final userHash = sha256.convert(utf8.encode(rawUsername)).toString();
      final masterPassword = _passwordController.text;

      final parameters = VaultParameters(
        schemaVersion: 1,
        cipher: 'sqlcipher',
        kdf: 'argon2id',
        memory: 131072,
        iterations: 3,
        parallelism: 4,
        salt: _generateSecureSalt(),
        createdAt: DateTime.now().toUtc(),
      );

      await widget.vaultService.createAndUploadNewVault(
        userHash,
        masterPassword,
        parameters,
      );

      _passwordController.clear();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coffre créé avec succès ! Connectez-vous.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
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
      appBar: AppBar(title: const Text('Créer un nouveau coffre')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Identifiant (ex: prenom+date)',
                    border: OutlineInputBorder(),
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
                  ),
                  enabled: !_isLoading,
                  validator: (value) => value == null || value.isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _fillRandomPassword,
                  icon: const Icon(Icons.casino),
                  label: const Text('Générer une phrase secrète robuste'),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                ElevatedButton(
                  onPressed: _isLoading ? null : _initializeVault,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Initialiser le coffre sur pCloud'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}