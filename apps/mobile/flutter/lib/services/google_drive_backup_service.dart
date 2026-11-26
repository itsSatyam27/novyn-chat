import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'firebase_configuration.dart';
import 'backup_progress.dart';

/// Stores only password-encrypted Novyn backup envelopes in Drive's hidden
/// appDataFolder. The Drive OAuth scope cannot access the user's other files.
class GoogleDriveBackupService {
  GoogleDriveBackupService._();

  static const _scope = 'https://www.googleapis.com/auth/drive.appdata';
  static const _fileName = 'novyn-chat-backup.json';
  static final _googleSignIn = GoogleSignIn(
    scopes: const [_scope],
    serverClientId: FirebaseConfiguration.googleWebClientId,
  );

  static Future<String> _accessToken({bool interactive = true}) async {
    final account = interactive
        ? await _googleSignIn.signIn()
        : await _googleSignIn.signInSilently();
    if (account == null) throw StateError('Google Drive sign-in was cancelled.');
    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Google did not grant Novyn access to its app backup folder.');
    }
    return token;
  }

  static Future<Map<String, dynamic>?> _findBackup(String token) async {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'spaces': 'appDataFolder',
      'q': "name = '$_fileName' and trashed = false",
      'pageSize': '10',
      'orderBy': 'modifiedTime desc',
      'fields': 'files(id,name,modifiedTime,size)',
    });
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Google Drive could not list Novyn backups (${response.statusCode}).');
    }
    final data = jsonDecode(response.body);
    if (data is! Map || data['files'] is! List || (data['files'] as List).isEmpty) return null;
    final files = (data['files'] as List).whereType<Map>().toList()
      ..sort((a, b) => (b['modifiedTime']?.toString() ?? '')
          .compareTo(a['modifiedTime']?.toString() ?? ''));
    return files.isEmpty ? null : Map<String, dynamic>.from(files.first);
  }

  static Future<void> save(
    Uint8List encryptedBackup, {
    bool interactive = true,
    void Function(int sentBytes, int totalBytes)? onProgress,
    BackupCancellationCheck? checkCancelled,
  }) async {
    checkCancelled?.call();
    final token = await _accessToken(interactive: interactive);
    checkCancelled?.call();
    final existing = await _findBackup(token);
    checkCancelled?.call();
    final boundary = 'novyn_${Random.secure().nextInt(1 << 32)}';
    final metadata = jsonEncode({
      'name': _fileName,
      if (existing == null) 'parents': ['appDataFolder'],
      'mimeType': 'application/octet-stream',
    });
    final prefix = utf8.encode(
      '--$boundary\r\n'
      'Content-Type: application/json; charset=UTF-8\r\n\r\n'
      '$metadata\r\n'
      '--$boundary\r\n'
      'Content-Type: application/octet-stream\r\n\r\n',
    );
    final suffix = utf8.encode('\r\n--$boundary--');
    final body = Uint8List(prefix.length + encryptedBackup.length + suffix.length)
      ..setRange(0, prefix.length, prefix)
      ..setRange(prefix.length, prefix.length + encryptedBackup.length, encryptedBackup)
      ..setRange(prefix.length + encryptedBackup.length, prefix.length + encryptedBackup.length + suffix.length, suffix);
    final uploadPath = existing == null
        ? '/upload/drive/v3/files'
        : '/upload/drive/v3/files/${Uri.encodeComponent(existing['id'].toString())}';
    final request = http.StreamedRequest(existing == null ? 'POST' : 'PATCH', Uri.https(
      'www.googleapis.com',
      uploadPath,
      {'uploadType': 'multipart', 'fields': 'id,name,modifiedTime'},
    ))
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Content-Type'] = 'multipart/related; boundary=$boundary'
      ..contentLength = body.length;

    // Send in bounded chunks so the UI and Android notification can report
    // actual upload progress and cancellation can close the active request.
    final client = http.Client();
    final responseFuture = client.send(request);
    var sentBytes = 0;
    try {
      const chunkSize = 64 * 1024;
      while (sentBytes < body.length) {
        checkCancelled?.call();
        final end = (sentBytes + chunkSize).clamp(0, body.length).toInt();
        request.sink.add(body.sublist(sentBytes, end));
        sentBytes = end;
        onProgress?.call(sentBytes, body.length);
        await Future<void>.delayed(Duration.zero);
      }
      checkCancelled?.call();
      await request.sink.close();
      final streamed = await responseFuture;
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final details = await streamed.stream.bytesToString();
        debugPrint('[NovynBackup] Drive upload failed: ${streamed.statusCode} $details');
        throw StateError('Google Drive could not save the encrypted backup (${streamed.statusCode}).');
      }
      checkCancelled?.call();
    } finally {
      client.close();
    }
  }

  static Future<Uint8List?> restore() async {
    final token = await _accessToken();
    final file = await _findBackup(token);
    if (file == null) return null;
    final id = Uri.encodeComponent(file['id']?.toString() ?? '');
    if (id.isEmpty) throw const FormatException('The Drive backup entry is invalid.');
    final response = await http.get(
      Uri.https('www.googleapis.com', '/drive/v3/files/$id', {'alt': 'media'}),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Google Drive could not download the backup (${response.statusCode}).');
    }
    if (response.bodyBytes.length > 100 * 1024 * 1024) {
      throw const FormatException('The Drive backup is larger than 100 MB.');
    }
    return response.bodyBytes;
  }
}
