import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/password_entry.dart';
import '../application/vault_service.dart';
import 'add_password_screen.dart';
import 'login_screen.dart';

class VaultScreen extends StatefulWidget {
  final VaultService vaultService;
  final bool isOfflineMode;
  final String userHash;

  const VaultScreen({
    Key? key,
    required this.vaultService,
    required this.isOfflineMode,
    required this.userHash,
  }) : super(key: key);

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  List<PasswordEntry> _passwords = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadPasswords();
  }

  Future<void> _loadPasswords() async {
    try {
      final passwords = await widget.vaultService.repository.getCurrentPasswords();
      if (mounted) {
        setState(() {
          _passwords = passwords;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _secureCopy(String text, String fieldName) async {
    await Clipboard.setData(ClipboardData(text: text));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fieldName copié. Effacement dans 20s...'),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    Future.delayed(const Duration(seconds: 20), () async {
      final currentClipboard = await Clipboard.getData(Clipboard.kTextPlain);
      if (currentClipboard != null && currentClipboard.text == text) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  Future<void> _lockAndExit() async {
    await widget.vaultService.lockVault();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            vaultService: widget.vaultService,
            networkChecker: (context.findAncestorWidgetOfExactType<MaterialApp>()!.home as LoginScreen).networkChecker,
            secretRepository: (context.findAncestorWidgetOfExactType<MaterialApp>()!.home as LoginScreen).secretRepository,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Coffre-Fort'),
        backgroundColor: widget.isOfflineMode ? Colors.orange.shade800 : Colors.blueGrey,
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.lock),
            onPressed: _lockAndExit,
            tooltip: 'Verrouiller',
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.isOfflineMode)
            Container(
              width: double.infinity,
              color: Colors.orange.shade100,
              padding: const EdgeInsets.all(8.0),
              child: const Text(
                'MODE HORS-LIGNE - Lecture seule',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _passwords.isEmpty
                ? const Center(child: Text('Aucun mot de passe trouvé.'))
                : ListView.builder(
              itemCount: _passwords.length,
              itemBuilder: (context, index) {
                final entry = _passwords[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(entry.username),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.person_outline),
                          onPressed: () => _secureCopy(entry.username, 'Identifiant'),
                          tooltip: 'Copier l\'identifiant',
                        ),
                        IconButton(
                          icon: const Icon(Icons.key),
                          onPressed: () => _secureCopy(entry.password, 'Mot de passe'),
                          tooltip: 'Copier le mot de passe',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.isOfflineMode
          ? null
          : FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddPasswordScreen(
                passwordRepository: widget.vaultService.repository,
              ),
            ),
          );

          if (result == true) {
            await _loadPasswords();

            setState(() => _isSyncing = true);
            try {
              await widget.vaultService.syncVaultToCloud(widget.userHash);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coffre synchronisé sur pCloud.'), backgroundColor: Colors.green),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur de synchro : $e'), backgroundColor: Colors.red),
                );
              }
            } finally {
              if (mounted) setState(() => _isSyncing = false);
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}