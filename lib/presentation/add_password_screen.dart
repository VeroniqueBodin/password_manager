import 'dart:math';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../domain/i_store_passwords.dart';
import '../domain/password_entry.dart';

class AddPasswordScreen extends StatefulWidget {
  final IStorePasswords passwordRepository;

  const AddPasswordScreen({
    Key? key,
    required this.passwordRepository,
  }) : super(key: key);

  @override
  State<AddPasswordScreen> createState() => _AddPasswordScreenState();
}

class _AddPasswordScreenState extends State<AddPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _urlController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSaving = false;
  double _passwordLength = 16;

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _generateStrongPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()-_=+';
    final random = Random.secure();
    final result = StringBuffer();

    for (int i = 0; i < _passwordLength.toInt(); i++) {
      result.write(chars[random.nextInt(chars.length)]);
    }

    setState(() {
      _passwordController.text = result.toString();
    });
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final newEntry = PasswordEntry(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        url: _urlController.text.trim(),
        notes: _notesController.text.trim(),
        createdAt: DateTime.now().toUtc(),
        isCurrent: true,
      );

      await widget.passwordRepository.addOrUpdatePassword(newEntry);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de sauvegarde : ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un mot de passe')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Titre (ex: Netflix)'),
                  validator: (value) => value == null || value.isEmpty ? 'Requis' : null,
                ),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Identifiant / Email'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Mot de passe'),
                        validator: (value) => value == null || value.isEmpty ? 'Requis' : null,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.autorenew),
                      onPressed: _generateStrongPassword,
                      tooltip: 'Générer',
                    ),
                  ],
                ),
                Slider(
                  value: _passwordLength,
                  min: 8,
                  max: 64,
                  divisions: 56,
                  label: '${_passwordLength.toInt()} caractères',
                  onChanged: (value) {
                    setState(() {
                      _passwordLength = value;
                    });
                  },
                ),
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: 'URL (optionnel)'),
                ),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optionnel)'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _savePassword,
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : const Text('Sauvegarder et Chiffrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}