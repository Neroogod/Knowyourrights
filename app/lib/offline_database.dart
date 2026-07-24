import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

part 'offline_database.g.dart';

class OfflineContentRows extends Table {
  TextColumn get id => text()();
  TextColumn get layer => text()();
  TextColumn get jurisdiction => text()();
  TextColumn get recordType => text()();
  TextColumn get jsonBody => text()();
  IntColumn get contentVersion => integer()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {layer, jurisdiction, recordType, id};
}

class ContentSyncStates extends Table {
  TextColumn get layer => text()();
  TextColumn get jurisdiction => text()();
  IntColumn get contentVersion => integer().withDefault(const Constant(0))();
  TextColumn get etag => text().nullable()();
  TextColumn get checksum => text().nullable()();
  TextColumn get keyId => text().nullable()();
  DateTimeColumn get lastCheckedAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {layer, jurisdiction};
}

class OfflineAlertQueueRows extends Table {
  TextColumn get idempotencyKey => text()();
  TextColumn get jsonBody => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextAttemptAt => dateTime()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {idempotencyKey};
}

class EncryptedContactCacheRows extends Table {
  TextColumn get accountKey => text()();
  TextColumn get encryptedPayload => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {accountKey};
}

class SavedContentRows extends Table {
  TextColumn get contentId => text()();
  TextColumn get contentType => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {contentType, contentId};
}

class DraftRows extends Table {
  TextColumn get id => text()();
  TextColumn get draftType => text()();
  TextColumn get jsonBody => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    OfflineContentRows,
    ContentSyncStates,
    OfflineAlertQueueRows,
    EncryptedContactCacheRows,
    SavedContentRows,
    DraftRows,
  ],
)
class OfflineDatabase extends _$OfflineDatabase {
  OfflineDatabase._() : super(_openConnection());

  static final OfflineDatabase instance = OfflineDatabase._();

  @override
  int get schemaVersion => 1;

  Future<List<Map<String, dynamic>>> records(
    String layer,
    String jurisdiction,
    String recordType,
  ) async {
    final rows =
        await (select(offlineContentRows)..where(
              (row) =>
                  row.layer.equals(layer) &
                  row.jurisdiction.equals(jurisdiction) &
                  row.recordType.equals(recordType),
            ))
            .get();
    return rows
        .map((row) => Map<String, dynamic>.from(jsonDecodeObject(row.jsonBody)))
        .toList();
  }
}

Map<String, dynamic> jsonDecodeObject(String source) {
  // Kept here to ensure every JSON read has one typed validation boundary.
  return Map<String, dynamic>.from(const JsonDecoder().convert(source) as Map);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(
      path.join(directory.path, 'knowyourrights_offline.sqlite'),
    );
    return NativeDatabase.createInBackground(file);
  });
}
