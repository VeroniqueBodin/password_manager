import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:retry/retry.dart';
import '../domain/i_synchronize_vault_files.dart';
import '../domain/i_store_local_secrets.dart';
import '../domain/vault_parameters.dart';

class WebDavVaultSynchronizer implements ISynchronizeVaultFiles {
  final IStoreLocalSecrets _secretRepository;
  final String _baseUrl;
  final http.Client _client;

  WebDavVaultSynchronizer(
      this._secretRepository,
      this._baseUrl,
      this._client,
      );

  Future<T> _withRetry<T>(Future<T> Function() action) async {
    try {
      return await retry(
        action,
        retryIf: (e) => e is SocketException || e is TimeoutException,
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 2),
      );
    } on SocketException {
      throw Exception('Erreur réseau : Impossible de joindre pCloud. Vérifiez votre connexion internet.');
    } on TimeoutException {
      throw Exception('Erreur réseau : Le serveur pCloud met trop de temps à répondre (Délai dépassé).');
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final credentials = await _secretRepository.getWebDavCredentials();
    final username = credentials['username'] ?? '';
    final password = credentials['password'] ?? '';
    final basicAuth = base64Encode(utf8.encode('$username:$password'));

    return {
      'Authorization': 'Basic $basicAuth',
      'Content-Type': 'application/octet-stream',
    };
  }

  @override
  Future<VaultParameters> fetchParameters(String userHash) async {
    return _withRetry(() async {
      final headers = await _getAuthHeaders();
      final url = Uri.parse('$_baseUrl/vaults/$userHash/meta.json');

      final response = await _client.get(url, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Impossible de récupérer les métadonnées. Code: ${response.statusCode}');
      }

      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      return VaultParameters.fromJson(jsonMap);
    });
  }

  @override
  Future<void> uploadParameters(String userHash, VaultParameters parameters) async {
    return _withRetry(() async {
      final headers = await _getAuthHeaders();

      final folderUrl = Uri.parse('$_baseUrl/vaults/$userHash/');
      final mkcolResponse = await _client.send(
          http.Request('MKCOL', folderUrl)..headers.addAll(headers)
      ).timeout(const Duration(seconds: 10));

      if (mkcolResponse.statusCode != 201 && mkcolResponse.statusCode != 405) {
        throw Exception('Impossible de créer le dossier utilisateur. Code: ${mkcolResponse.statusCode}');
      }

      final url = Uri.parse('$_baseUrl/vaults/$userHash/meta.json');
      final response = await _client.put(
        url,
        headers: headers,
        body: jsonEncode(parameters.toJson()),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 400) {
        throw Exception('Erreur lors de la sauvegarde des métadonnées.');
      }
    });
  }

  @override
  Future<File> downloadVaultFile(String userHash, String destinationPath) async {
    return _withRetry(() async {
      final headers = await _getAuthHeaders();
      final url = Uri.parse('$_baseUrl/vaults/$userHash/vault.db');

      final response = await _client.get(url, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 && response.statusCode != 404) {
        throw Exception('Erreur de téléchargement du coffre.');
      }

      final file = File(destinationPath);
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes, flush: true);
      }

      return file;
    });
  }

  @override
  Future<void> uploadVaultFile(String userHash, File localVaultFile) async {
    return _withRetry(() async {
      final headers = await _getAuthHeaders();
      final tempUrl = Uri.parse('$_baseUrl/vaults/$userHash/vault_temp.db');
      final finalUrl = Uri.parse('$_baseUrl/vaults/$userHash/vault.db');

      final fileBytes = await localVaultFile.readAsBytes();

      final putResponse = await _client.put(
        tempUrl,
        headers: headers,
        body: fileBytes,
      ).timeout(const Duration(seconds: 30));

      if (putResponse.statusCode >= 400) {
        throw Exception('Échec de l\'envoi du fichier temporaire.');
      }

      final moveHeaders = Map<String, String>.from(headers)
        ..['Destination'] = finalUrl.toString()
        ..['Overwrite'] = 'T';

      final moveResponse = await _client.send(
          http.Request('MOVE', tempUrl)..headers.addAll(moveHeaders)
      ).timeout(const Duration(seconds: 10));

      if (moveResponse.statusCode >= 400) {
        throw Exception('Échec du remplacement atomique sur le serveur.');
      }
    });
  }

  @override
  Future<void> createRollingBackup(String userHash) async {
    return _withRetry(() async {
      final headers = await _getAuthHeaders();

      final backupFolderUrl = Uri.parse('$_baseUrl/vaults/$userHash/backups/');
      await _client.send(
          http.Request('MKCOL', backupFolderUrl)..headers.addAll(headers)
      ).timeout(const Duration(seconds: 10));

      final sourceUrl = Uri.parse('$_baseUrl/vaults/$userHash/vault.db');
      final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final backupUrl = Uri.parse('$_baseUrl/vaults/$userHash/backups/vault_$timestamp.db');

      final copyHeaders = Map<String, String>.from(headers)
        ..['Destination'] = backupUrl.toString()
        ..['Overwrite'] = 'F';

      final copyResponse = await _client.send(
          http.Request('COPY', sourceUrl)..headers.addAll(copyHeaders)
      ).timeout(const Duration(seconds: 15));

      if (copyResponse.statusCode >= 400 && copyResponse.statusCode != 404) {
        throw Exception('Échec de la création de la sauvegarde rotative.');
      }
    });
  }
}