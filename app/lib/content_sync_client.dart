import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'offline_database.dart';

class ContentIntegrityException implements Exception {
  final String message;
  const ContentIntegrityException(this.message);
  @override
  String toString() => message;
}

class ContentPackSyncClient {
  ContentPackSyncClient({
    required this.database,
    http.Client? client,
    FlutterSecureStorage? secureStorage,
  }) : _client = client ?? http.Client(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _pinnedPublicKey = 'kyr_content_signing_public_key';
  static const _jurisdiction = 'NG-Federal';
  final OfflineDatabase database;
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;

  Future<void> syncAll() async {
    final publicKey = await _trustedPublicKey();
    for (final layer in const ['rights', 'students', 'company']) {
      await _syncLayer(layer, publicKey);
    }
  }

  Future<String> _trustedPublicKey() async {
    final response = await _client
        .get(Uri.parse('$kBaseUrl/v1/content-packs/config'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw const ContentIntegrityException(
        'Could not load the content-signing configuration.',
      );
    }
    final remote =
        (jsonDecode(response.body) as Map<String, dynamic>)['public_key']
            as String;
    final pinned = await _secureStorage.read(key: _pinnedPublicKey);
    if (pinned != null && pinned != remote) {
      throw const ContentIntegrityException(
        'The content-signing key changed unexpectedly. Update the app before syncing.',
      );
    }
    if (pinned == null) {
      await _secureStorage.write(key: _pinnedPublicKey, value: remote);
    }
    return remote;
  }

  Future<void> _syncLayer(String layer, String publicKey) async {
    final state =
        await (database.select(database.contentSyncStates)..where(
              (row) =>
                  row.layer.equals(layer) &
                  row.jurisdiction.equals(_jurisdiction),
            ))
            .getSingleOrNull();
    final request = http.Request(
      'GET',
      Uri.parse(
        '$kBaseUrl/v1/content-packs/$layer'
        '?since=${state?.contentVersion ?? 0}&jurisdiction=$_jurisdiction',
      ),
    );
    if (state?.etag != null) request.headers['If-None-Match'] = state!.etag!;
    try {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 12));
      if (streamed.statusCode == 304) {
        await _saveState(
          layer,
          version: state?.contentVersion ?? 0,
          etag: streamed.headers['etag'] ?? state?.etag,
          checksum: state?.checksum,
          keyId: state?.keyId,
        );
        return;
      }
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        throw ContentIntegrityException('Content sync failed for $layer.');
      }
      final envelope = Map<String, dynamic>.from(jsonDecode(body) as Map);
      await _verify(envelope, publicKey);
      await _apply(layer, envelope, streamed.headers['etag']);
    } catch (error) {
      await _saveState(
        layer,
        version: state?.contentVersion ?? 0,
        etag: state?.etag,
        checksum: state?.checksum,
        keyId: state?.keyId,
        error: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> _verify(Map<String, dynamic> envelope, String publicKey) async {
    final signatureText = envelope.remove('signature') as String?;
    if (signatureText == null) {
      throw const ContentIntegrityException('Content pack is unsigned.');
    }
    final signature = Signature(
      _decodeBase64(signatureText),
      publicKey: SimplePublicKey(
        _decodeBase64(publicKey),
        type: KeyPairType.ed25519,
      ),
    );
    final valid = await Ed25519().verify(
      utf8.encode(_canonicalJson(envelope)),
      signature: signature,
    );
    if (!valid) {
      throw const ContentIntegrityException(
        'Content signature verification failed.',
      );
    }
    final upserts = Map<String, dynamic>.from(
      envelope['upserts'] as Map? ?? {},
    );
    final digest = await Sha256().hash(utf8.encode(_canonicalJson(upserts)));
    if (_hex(digest.bytes) != envelope['checksum']) {
      throw const ContentIntegrityException(
        'Content checksum verification failed.',
      );
    }
  }

  Future<void> _apply(
    String layer,
    Map<String, dynamic> envelope,
    String? etag,
  ) async {
    final version = envelope['content_version'] as int;
    final upserts = Map<String, dynamic>.from(
      envelope['upserts'] as Map? ?? {},
    );
    await database.transaction(() async {
      if (upserts.isNotEmpty) {
        await (database.delete(database.offlineContentRows)..where(
              (row) =>
                  row.layer.equals(layer) &
                  row.jurisdiction.equals(_jurisdiction),
            ))
            .go();
        for (final entry in upserts.entries) {
          for (final raw in (entry.value as List? ?? const [])) {
            final record = Map<String, dynamic>.from(raw as Map);
            await database
                .into(database.offlineContentRows)
                .insert(
                  OfflineContentRowsCompanion.insert(
                    id: record['id'] as String,
                    layer: layer,
                    jurisdiction: _jurisdiction,
                    recordType: entry.key,
                    jsonBody: jsonEncode(record),
                    contentVersion: version,
                    updatedAt: DateTime.now().toUtc(),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
          }
        }
      }
      await _saveState(
        layer,
        version: version,
        etag: etag,
        checksum: envelope['checksum'] as String?,
        keyId: envelope['key_id'] as String?,
      );
    });
  }

  Future<void> _saveState(
    String layer, {
    required int version,
    String? etag,
    String? checksum,
    String? keyId,
    String? error,
  }) => database
      .into(database.contentSyncStates)
      .insert(
        ContentSyncStatesCompanion.insert(
          layer: layer,
          jurisdiction: _jurisdiction,
          contentVersion: Value(version),
          etag: Value(etag),
          checksum: Value(checksum),
          keyId: Value(keyId),
          lastCheckedAt: Value(DateTime.now().toUtc()),
          lastError: Value(error),
        ),
        mode: InsertMode.insertOrReplace,
      );

  static List<int> _decodeBase64(String value) =>
      base64Url.decode(value.padRight((value.length + 3) ~/ 4 * 4, '='));

  static String _hex(List<int> bytes) =>
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

  static String _canonicalJson(Object? value) => jsonEncode(_sort(value));

  static Object? _sort(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {for (final key in keys) key: _sort(value[key])};
    }
    if (value is List) return value.map(_sort).toList();
    return value;
  }
}
