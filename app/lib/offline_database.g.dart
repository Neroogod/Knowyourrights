// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_database.dart';

// ignore_for_file: type=lint
class $OfflineContentRowsTable extends OfflineContentRows
    with TableInfo<$OfflineContentRowsTable, OfflineContentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineContentRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerMeta = const VerificationMeta('layer');
  @override
  late final GeneratedColumn<String> layer = GeneratedColumn<String>(
    'layer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jurisdictionMeta = const VerificationMeta(
    'jurisdiction',
  );
  @override
  late final GeneratedColumn<String> jurisdiction = GeneratedColumn<String>(
    'jurisdiction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordTypeMeta = const VerificationMeta(
    'recordType',
  );
  @override
  late final GeneratedColumn<String> recordType = GeneratedColumn<String>(
    'record_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonBodyMeta = const VerificationMeta(
    'jsonBody',
  );
  @override
  late final GeneratedColumn<String> jsonBody = GeneratedColumn<String>(
    'json_body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentVersionMeta = const VerificationMeta(
    'contentVersion',
  );
  @override
  late final GeneratedColumn<int> contentVersion = GeneratedColumn<int>(
    'content_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    layer,
    jurisdiction,
    recordType,
    jsonBody,
    contentVersion,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_content_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineContentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('layer')) {
      context.handle(
        _layerMeta,
        layer.isAcceptableOrUnknown(data['layer']!, _layerMeta),
      );
    } else if (isInserting) {
      context.missing(_layerMeta);
    }
    if (data.containsKey('jurisdiction')) {
      context.handle(
        _jurisdictionMeta,
        jurisdiction.isAcceptableOrUnknown(
          data['jurisdiction']!,
          _jurisdictionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_jurisdictionMeta);
    }
    if (data.containsKey('record_type')) {
      context.handle(
        _recordTypeMeta,
        recordType.isAcceptableOrUnknown(data['record_type']!, _recordTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_recordTypeMeta);
    }
    if (data.containsKey('json_body')) {
      context.handle(
        _jsonBodyMeta,
        jsonBody.isAcceptableOrUnknown(data['json_body']!, _jsonBodyMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonBodyMeta);
    }
    if (data.containsKey('content_version')) {
      context.handle(
        _contentVersionMeta,
        contentVersion.isAcceptableOrUnknown(
          data['content_version']!,
          _contentVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentVersionMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {layer, jurisdiction, recordType, id};
  @override
  OfflineContentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineContentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      layer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer'],
      )!,
      jurisdiction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jurisdiction'],
      )!,
      recordType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_type'],
      )!,
      jsonBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json_body'],
      )!,
      contentVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_version'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $OfflineContentRowsTable createAlias(String alias) {
    return $OfflineContentRowsTable(attachedDatabase, alias);
  }
}

class OfflineContentRow extends DataClass
    implements Insertable<OfflineContentRow> {
  final String id;
  final String layer;
  final String jurisdiction;
  final String recordType;
  final String jsonBody;
  final int contentVersion;
  final DateTime updatedAt;
  const OfflineContentRow({
    required this.id,
    required this.layer,
    required this.jurisdiction,
    required this.recordType,
    required this.jsonBody,
    required this.contentVersion,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['layer'] = Variable<String>(layer);
    map['jurisdiction'] = Variable<String>(jurisdiction);
    map['record_type'] = Variable<String>(recordType);
    map['json_body'] = Variable<String>(jsonBody);
    map['content_version'] = Variable<int>(contentVersion);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OfflineContentRowsCompanion toCompanion(bool nullToAbsent) {
    return OfflineContentRowsCompanion(
      id: Value(id),
      layer: Value(layer),
      jurisdiction: Value(jurisdiction),
      recordType: Value(recordType),
      jsonBody: Value(jsonBody),
      contentVersion: Value(contentVersion),
      updatedAt: Value(updatedAt),
    );
  }

  factory OfflineContentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineContentRow(
      id: serializer.fromJson<String>(json['id']),
      layer: serializer.fromJson<String>(json['layer']),
      jurisdiction: serializer.fromJson<String>(json['jurisdiction']),
      recordType: serializer.fromJson<String>(json['recordType']),
      jsonBody: serializer.fromJson<String>(json['jsonBody']),
      contentVersion: serializer.fromJson<int>(json['contentVersion']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'layer': serializer.toJson<String>(layer),
      'jurisdiction': serializer.toJson<String>(jurisdiction),
      'recordType': serializer.toJson<String>(recordType),
      'jsonBody': serializer.toJson<String>(jsonBody),
      'contentVersion': serializer.toJson<int>(contentVersion),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OfflineContentRow copyWith({
    String? id,
    String? layer,
    String? jurisdiction,
    String? recordType,
    String? jsonBody,
    int? contentVersion,
    DateTime? updatedAt,
  }) => OfflineContentRow(
    id: id ?? this.id,
    layer: layer ?? this.layer,
    jurisdiction: jurisdiction ?? this.jurisdiction,
    recordType: recordType ?? this.recordType,
    jsonBody: jsonBody ?? this.jsonBody,
    contentVersion: contentVersion ?? this.contentVersion,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OfflineContentRow copyWithCompanion(OfflineContentRowsCompanion data) {
    return OfflineContentRow(
      id: data.id.present ? data.id.value : this.id,
      layer: data.layer.present ? data.layer.value : this.layer,
      jurisdiction: data.jurisdiction.present
          ? data.jurisdiction.value
          : this.jurisdiction,
      recordType: data.recordType.present
          ? data.recordType.value
          : this.recordType,
      jsonBody: data.jsonBody.present ? data.jsonBody.value : this.jsonBody,
      contentVersion: data.contentVersion.present
          ? data.contentVersion.value
          : this.contentVersion,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineContentRow(')
          ..write('id: $id, ')
          ..write('layer: $layer, ')
          ..write('jurisdiction: $jurisdiction, ')
          ..write('recordType: $recordType, ')
          ..write('jsonBody: $jsonBody, ')
          ..write('contentVersion: $contentVersion, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    layer,
    jurisdiction,
    recordType,
    jsonBody,
    contentVersion,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineContentRow &&
          other.id == this.id &&
          other.layer == this.layer &&
          other.jurisdiction == this.jurisdiction &&
          other.recordType == this.recordType &&
          other.jsonBody == this.jsonBody &&
          other.contentVersion == this.contentVersion &&
          other.updatedAt == this.updatedAt);
}

class OfflineContentRowsCompanion extends UpdateCompanion<OfflineContentRow> {
  final Value<String> id;
  final Value<String> layer;
  final Value<String> jurisdiction;
  final Value<String> recordType;
  final Value<String> jsonBody;
  final Value<int> contentVersion;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const OfflineContentRowsCompanion({
    this.id = const Value.absent(),
    this.layer = const Value.absent(),
    this.jurisdiction = const Value.absent(),
    this.recordType = const Value.absent(),
    this.jsonBody = const Value.absent(),
    this.contentVersion = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineContentRowsCompanion.insert({
    required String id,
    required String layer,
    required String jurisdiction,
    required String recordType,
    required String jsonBody,
    required int contentVersion,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       layer = Value(layer),
       jurisdiction = Value(jurisdiction),
       recordType = Value(recordType),
       jsonBody = Value(jsonBody),
       contentVersion = Value(contentVersion),
       updatedAt = Value(updatedAt);
  static Insertable<OfflineContentRow> custom({
    Expression<String>? id,
    Expression<String>? layer,
    Expression<String>? jurisdiction,
    Expression<String>? recordType,
    Expression<String>? jsonBody,
    Expression<int>? contentVersion,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (layer != null) 'layer': layer,
      if (jurisdiction != null) 'jurisdiction': jurisdiction,
      if (recordType != null) 'record_type': recordType,
      if (jsonBody != null) 'json_body': jsonBody,
      if (contentVersion != null) 'content_version': contentVersion,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineContentRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? layer,
    Value<String>? jurisdiction,
    Value<String>? recordType,
    Value<String>? jsonBody,
    Value<int>? contentVersion,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return OfflineContentRowsCompanion(
      id: id ?? this.id,
      layer: layer ?? this.layer,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      recordType: recordType ?? this.recordType,
      jsonBody: jsonBody ?? this.jsonBody,
      contentVersion: contentVersion ?? this.contentVersion,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (layer.present) {
      map['layer'] = Variable<String>(layer.value);
    }
    if (jurisdiction.present) {
      map['jurisdiction'] = Variable<String>(jurisdiction.value);
    }
    if (recordType.present) {
      map['record_type'] = Variable<String>(recordType.value);
    }
    if (jsonBody.present) {
      map['json_body'] = Variable<String>(jsonBody.value);
    }
    if (contentVersion.present) {
      map['content_version'] = Variable<int>(contentVersion.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineContentRowsCompanion(')
          ..write('id: $id, ')
          ..write('layer: $layer, ')
          ..write('jurisdiction: $jurisdiction, ')
          ..write('recordType: $recordType, ')
          ..write('jsonBody: $jsonBody, ')
          ..write('contentVersion: $contentVersion, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentSyncStatesTable extends ContentSyncStates
    with TableInfo<$ContentSyncStatesTable, ContentSyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentSyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _layerMeta = const VerificationMeta('layer');
  @override
  late final GeneratedColumn<String> layer = GeneratedColumn<String>(
    'layer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jurisdictionMeta = const VerificationMeta(
    'jurisdiction',
  );
  @override
  late final GeneratedColumn<String> jurisdiction = GeneratedColumn<String>(
    'jurisdiction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentVersionMeta = const VerificationMeta(
    'contentVersion',
  );
  @override
  late final GeneratedColumn<int> contentVersion = GeneratedColumn<int>(
    'content_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keyIdMeta = const VerificationMeta('keyId');
  @override
  late final GeneratedColumn<String> keyId = GeneratedColumn<String>(
    'key_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastCheckedAtMeta = const VerificationMeta(
    'lastCheckedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastCheckedAt =
      GeneratedColumn<DateTime>(
        'last_checked_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    layer,
    jurisdiction,
    contentVersion,
    etag,
    checksum,
    keyId,
    lastCheckedAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentSyncState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('layer')) {
      context.handle(
        _layerMeta,
        layer.isAcceptableOrUnknown(data['layer']!, _layerMeta),
      );
    } else if (isInserting) {
      context.missing(_layerMeta);
    }
    if (data.containsKey('jurisdiction')) {
      context.handle(
        _jurisdictionMeta,
        jurisdiction.isAcceptableOrUnknown(
          data['jurisdiction']!,
          _jurisdictionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_jurisdictionMeta);
    }
    if (data.containsKey('content_version')) {
      context.handle(
        _contentVersionMeta,
        contentVersion.isAcceptableOrUnknown(
          data['content_version']!,
          _contentVersionMeta,
        ),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    }
    if (data.containsKey('key_id')) {
      context.handle(
        _keyIdMeta,
        keyId.isAcceptableOrUnknown(data['key_id']!, _keyIdMeta),
      );
    }
    if (data.containsKey('last_checked_at')) {
      context.handle(
        _lastCheckedAtMeta,
        lastCheckedAt.isAcceptableOrUnknown(
          data['last_checked_at']!,
          _lastCheckedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {layer, jurisdiction};
  @override
  ContentSyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentSyncState(
      layer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}layer'],
      )!,
      jurisdiction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jurisdiction'],
      )!,
      contentVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_version'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      ),
      keyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key_id'],
      ),
      lastCheckedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_checked_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $ContentSyncStatesTable createAlias(String alias) {
    return $ContentSyncStatesTable(attachedDatabase, alias);
  }
}

class ContentSyncState extends DataClass
    implements Insertable<ContentSyncState> {
  final String layer;
  final String jurisdiction;
  final int contentVersion;
  final String? etag;
  final String? checksum;
  final String? keyId;
  final DateTime? lastCheckedAt;
  final String? lastError;
  const ContentSyncState({
    required this.layer,
    required this.jurisdiction,
    required this.contentVersion,
    this.etag,
    this.checksum,
    this.keyId,
    this.lastCheckedAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['layer'] = Variable<String>(layer);
    map['jurisdiction'] = Variable<String>(jurisdiction);
    map['content_version'] = Variable<int>(contentVersion);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || checksum != null) {
      map['checksum'] = Variable<String>(checksum);
    }
    if (!nullToAbsent || keyId != null) {
      map['key_id'] = Variable<String>(keyId);
    }
    if (!nullToAbsent || lastCheckedAt != null) {
      map['last_checked_at'] = Variable<DateTime>(lastCheckedAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  ContentSyncStatesCompanion toCompanion(bool nullToAbsent) {
    return ContentSyncStatesCompanion(
      layer: Value(layer),
      jurisdiction: Value(jurisdiction),
      contentVersion: Value(contentVersion),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      checksum: checksum == null && nullToAbsent
          ? const Value.absent()
          : Value(checksum),
      keyId: keyId == null && nullToAbsent
          ? const Value.absent()
          : Value(keyId),
      lastCheckedAt: lastCheckedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory ContentSyncState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentSyncState(
      layer: serializer.fromJson<String>(json['layer']),
      jurisdiction: serializer.fromJson<String>(json['jurisdiction']),
      contentVersion: serializer.fromJson<int>(json['contentVersion']),
      etag: serializer.fromJson<String?>(json['etag']),
      checksum: serializer.fromJson<String?>(json['checksum']),
      keyId: serializer.fromJson<String?>(json['keyId']),
      lastCheckedAt: serializer.fromJson<DateTime?>(json['lastCheckedAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'layer': serializer.toJson<String>(layer),
      'jurisdiction': serializer.toJson<String>(jurisdiction),
      'contentVersion': serializer.toJson<int>(contentVersion),
      'etag': serializer.toJson<String?>(etag),
      'checksum': serializer.toJson<String?>(checksum),
      'keyId': serializer.toJson<String?>(keyId),
      'lastCheckedAt': serializer.toJson<DateTime?>(lastCheckedAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  ContentSyncState copyWith({
    String? layer,
    String? jurisdiction,
    int? contentVersion,
    Value<String?> etag = const Value.absent(),
    Value<String?> checksum = const Value.absent(),
    Value<String?> keyId = const Value.absent(),
    Value<DateTime?> lastCheckedAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => ContentSyncState(
    layer: layer ?? this.layer,
    jurisdiction: jurisdiction ?? this.jurisdiction,
    contentVersion: contentVersion ?? this.contentVersion,
    etag: etag.present ? etag.value : this.etag,
    checksum: checksum.present ? checksum.value : this.checksum,
    keyId: keyId.present ? keyId.value : this.keyId,
    lastCheckedAt: lastCheckedAt.present
        ? lastCheckedAt.value
        : this.lastCheckedAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  ContentSyncState copyWithCompanion(ContentSyncStatesCompanion data) {
    return ContentSyncState(
      layer: data.layer.present ? data.layer.value : this.layer,
      jurisdiction: data.jurisdiction.present
          ? data.jurisdiction.value
          : this.jurisdiction,
      contentVersion: data.contentVersion.present
          ? data.contentVersion.value
          : this.contentVersion,
      etag: data.etag.present ? data.etag.value : this.etag,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      keyId: data.keyId.present ? data.keyId.value : this.keyId,
      lastCheckedAt: data.lastCheckedAt.present
          ? data.lastCheckedAt.value
          : this.lastCheckedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentSyncState(')
          ..write('layer: $layer, ')
          ..write('jurisdiction: $jurisdiction, ')
          ..write('contentVersion: $contentVersion, ')
          ..write('etag: $etag, ')
          ..write('checksum: $checksum, ')
          ..write('keyId: $keyId, ')
          ..write('lastCheckedAt: $lastCheckedAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    layer,
    jurisdiction,
    contentVersion,
    etag,
    checksum,
    keyId,
    lastCheckedAt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentSyncState &&
          other.layer == this.layer &&
          other.jurisdiction == this.jurisdiction &&
          other.contentVersion == this.contentVersion &&
          other.etag == this.etag &&
          other.checksum == this.checksum &&
          other.keyId == this.keyId &&
          other.lastCheckedAt == this.lastCheckedAt &&
          other.lastError == this.lastError);
}

class ContentSyncStatesCompanion extends UpdateCompanion<ContentSyncState> {
  final Value<String> layer;
  final Value<String> jurisdiction;
  final Value<int> contentVersion;
  final Value<String?> etag;
  final Value<String?> checksum;
  final Value<String?> keyId;
  final Value<DateTime?> lastCheckedAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const ContentSyncStatesCompanion({
    this.layer = const Value.absent(),
    this.jurisdiction = const Value.absent(),
    this.contentVersion = const Value.absent(),
    this.etag = const Value.absent(),
    this.checksum = const Value.absent(),
    this.keyId = const Value.absent(),
    this.lastCheckedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentSyncStatesCompanion.insert({
    required String layer,
    required String jurisdiction,
    this.contentVersion = const Value.absent(),
    this.etag = const Value.absent(),
    this.checksum = const Value.absent(),
    this.keyId = const Value.absent(),
    this.lastCheckedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : layer = Value(layer),
       jurisdiction = Value(jurisdiction);
  static Insertable<ContentSyncState> custom({
    Expression<String>? layer,
    Expression<String>? jurisdiction,
    Expression<int>? contentVersion,
    Expression<String>? etag,
    Expression<String>? checksum,
    Expression<String>? keyId,
    Expression<DateTime>? lastCheckedAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (layer != null) 'layer': layer,
      if (jurisdiction != null) 'jurisdiction': jurisdiction,
      if (contentVersion != null) 'content_version': contentVersion,
      if (etag != null) 'etag': etag,
      if (checksum != null) 'checksum': checksum,
      if (keyId != null) 'key_id': keyId,
      if (lastCheckedAt != null) 'last_checked_at': lastCheckedAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentSyncStatesCompanion copyWith({
    Value<String>? layer,
    Value<String>? jurisdiction,
    Value<int>? contentVersion,
    Value<String?>? etag,
    Value<String?>? checksum,
    Value<String?>? keyId,
    Value<DateTime?>? lastCheckedAt,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return ContentSyncStatesCompanion(
      layer: layer ?? this.layer,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      contentVersion: contentVersion ?? this.contentVersion,
      etag: etag ?? this.etag,
      checksum: checksum ?? this.checksum,
      keyId: keyId ?? this.keyId,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (layer.present) {
      map['layer'] = Variable<String>(layer.value);
    }
    if (jurisdiction.present) {
      map['jurisdiction'] = Variable<String>(jurisdiction.value);
    }
    if (contentVersion.present) {
      map['content_version'] = Variable<int>(contentVersion.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (keyId.present) {
      map['key_id'] = Variable<String>(keyId.value);
    }
    if (lastCheckedAt.present) {
      map['last_checked_at'] = Variable<DateTime>(lastCheckedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentSyncStatesCompanion(')
          ..write('layer: $layer, ')
          ..write('jurisdiction: $jurisdiction, ')
          ..write('contentVersion: $contentVersion, ')
          ..write('etag: $etag, ')
          ..write('checksum: $checksum, ')
          ..write('keyId: $keyId, ')
          ..write('lastCheckedAt: $lastCheckedAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OfflineAlertQueueRowsTable extends OfflineAlertQueueRows
    with TableInfo<$OfflineAlertQueueRowsTable, OfflineAlertQueueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineAlertQueueRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonBodyMeta = const VerificationMeta(
    'jsonBody',
  );
  @override
  late final GeneratedColumn<String> jsonBody = GeneratedColumn<String>(
    'json_body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    idempotencyKey,
    jsonBody,
    attempts,
    createdAt,
    nextAttemptAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_alert_queue_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineAlertQueueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('json_body')) {
      context.handle(
        _jsonBodyMeta,
        jsonBody.isAcceptableOrUnknown(data['json_body']!, _jsonBodyMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonBodyMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptAtMeta);
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {idempotencyKey};
  @override
  OfflineAlertQueueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineAlertQueueRow(
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      jsonBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json_body'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $OfflineAlertQueueRowsTable createAlias(String alias) {
    return $OfflineAlertQueueRowsTable(attachedDatabase, alias);
  }
}

class OfflineAlertQueueRow extends DataClass
    implements Insertable<OfflineAlertQueueRow> {
  final String idempotencyKey;
  final String jsonBody;
  final int attempts;
  final DateTime createdAt;
  final DateTime nextAttemptAt;
  final String? lastError;
  const OfflineAlertQueueRow({
    required this.idempotencyKey,
    required this.jsonBody,
    required this.attempts,
    required this.createdAt,
    required this.nextAttemptAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['json_body'] = Variable<String>(jsonBody);
    map['attempts'] = Variable<int>(attempts);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  OfflineAlertQueueRowsCompanion toCompanion(bool nullToAbsent) {
    return OfflineAlertQueueRowsCompanion(
      idempotencyKey: Value(idempotencyKey),
      jsonBody: Value(jsonBody),
      attempts: Value(attempts),
      createdAt: Value(createdAt),
      nextAttemptAt: Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory OfflineAlertQueueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineAlertQueueRow(
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      jsonBody: serializer.fromJson<String>(json['jsonBody']),
      attempts: serializer.fromJson<int>(json['attempts']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      nextAttemptAt: serializer.fromJson<DateTime>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'jsonBody': serializer.toJson<String>(jsonBody),
      'attempts': serializer.toJson<int>(attempts),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'nextAttemptAt': serializer.toJson<DateTime>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  OfflineAlertQueueRow copyWith({
    String? idempotencyKey,
    String? jsonBody,
    int? attempts,
    DateTime? createdAt,
    DateTime? nextAttemptAt,
    Value<String?> lastError = const Value.absent(),
  }) => OfflineAlertQueueRow(
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    jsonBody: jsonBody ?? this.jsonBody,
    attempts: attempts ?? this.attempts,
    createdAt: createdAt ?? this.createdAt,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  OfflineAlertQueueRow copyWithCompanion(OfflineAlertQueueRowsCompanion data) {
    return OfflineAlertQueueRow(
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      jsonBody: data.jsonBody.present ? data.jsonBody.value : this.jsonBody,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineAlertQueueRow(')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('jsonBody: $jsonBody, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    idempotencyKey,
    jsonBody,
    attempts,
    createdAt,
    nextAttemptAt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineAlertQueueRow &&
          other.idempotencyKey == this.idempotencyKey &&
          other.jsonBody == this.jsonBody &&
          other.attempts == this.attempts &&
          other.createdAt == this.createdAt &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError);
}

class OfflineAlertQueueRowsCompanion
    extends UpdateCompanion<OfflineAlertQueueRow> {
  final Value<String> idempotencyKey;
  final Value<String> jsonBody;
  final Value<int> attempts;
  final Value<DateTime> createdAt;
  final Value<DateTime> nextAttemptAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const OfflineAlertQueueRowsCompanion({
    this.idempotencyKey = const Value.absent(),
    this.jsonBody = const Value.absent(),
    this.attempts = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineAlertQueueRowsCompanion.insert({
    required String idempotencyKey,
    required String jsonBody,
    this.attempts = const Value.absent(),
    required DateTime createdAt,
    required DateTime nextAttemptAt,
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : idempotencyKey = Value(idempotencyKey),
       jsonBody = Value(jsonBody),
       createdAt = Value(createdAt),
       nextAttemptAt = Value(nextAttemptAt);
  static Insertable<OfflineAlertQueueRow> custom({
    Expression<String>? idempotencyKey,
    Expression<String>? jsonBody,
    Expression<int>? attempts,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (jsonBody != null) 'json_body': jsonBody,
      if (attempts != null) 'attempts': attempts,
      if (createdAt != null) 'created_at': createdAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineAlertQueueRowsCompanion copyWith({
    Value<String>? idempotencyKey,
    Value<String>? jsonBody,
    Value<int>? attempts,
    Value<DateTime>? createdAt,
    Value<DateTime>? nextAttemptAt,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return OfflineAlertQueueRowsCompanion(
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      jsonBody: jsonBody ?? this.jsonBody,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt ?? this.createdAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (jsonBody.present) {
      map['json_body'] = Variable<String>(jsonBody.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineAlertQueueRowsCompanion(')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('jsonBody: $jsonBody, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EncryptedContactCacheRowsTable extends EncryptedContactCacheRows
    with TableInfo<$EncryptedContactCacheRowsTable, EncryptedContactCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EncryptedContactCacheRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountKeyMeta = const VerificationMeta(
    'accountKey',
  );
  @override
  late final GeneratedColumn<String> accountKey = GeneratedColumn<String>(
    'account_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encryptedPayloadMeta = const VerificationMeta(
    'encryptedPayload',
  );
  @override
  late final GeneratedColumn<String> encryptedPayload = GeneratedColumn<String>(
    'encrypted_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    accountKey,
    encryptedPayload,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'encrypted_contact_cache_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<EncryptedContactCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_key')) {
      context.handle(
        _accountKeyMeta,
        accountKey.isAcceptableOrUnknown(data['account_key']!, _accountKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_accountKeyMeta);
    }
    if (data.containsKey('encrypted_payload')) {
      context.handle(
        _encryptedPayloadMeta,
        encryptedPayload.isAcceptableOrUnknown(
          data['encrypted_payload']!,
          _encryptedPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_encryptedPayloadMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountKey};
  @override
  EncryptedContactCacheRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EncryptedContactCacheRow(
      accountKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_key'],
      )!,
      encryptedPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_payload'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EncryptedContactCacheRowsTable createAlias(String alias) {
    return $EncryptedContactCacheRowsTable(attachedDatabase, alias);
  }
}

class EncryptedContactCacheRow extends DataClass
    implements Insertable<EncryptedContactCacheRow> {
  final String accountKey;
  final String encryptedPayload;
  final DateTime updatedAt;
  const EncryptedContactCacheRow({
    required this.accountKey,
    required this.encryptedPayload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_key'] = Variable<String>(accountKey);
    map['encrypted_payload'] = Variable<String>(encryptedPayload);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EncryptedContactCacheRowsCompanion toCompanion(bool nullToAbsent) {
    return EncryptedContactCacheRowsCompanion(
      accountKey: Value(accountKey),
      encryptedPayload: Value(encryptedPayload),
      updatedAt: Value(updatedAt),
    );
  }

  factory EncryptedContactCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EncryptedContactCacheRow(
      accountKey: serializer.fromJson<String>(json['accountKey']),
      encryptedPayload: serializer.fromJson<String>(json['encryptedPayload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountKey': serializer.toJson<String>(accountKey),
      'encryptedPayload': serializer.toJson<String>(encryptedPayload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EncryptedContactCacheRow copyWith({
    String? accountKey,
    String? encryptedPayload,
    DateTime? updatedAt,
  }) => EncryptedContactCacheRow(
    accountKey: accountKey ?? this.accountKey,
    encryptedPayload: encryptedPayload ?? this.encryptedPayload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EncryptedContactCacheRow copyWithCompanion(
    EncryptedContactCacheRowsCompanion data,
  ) {
    return EncryptedContactCacheRow(
      accountKey: data.accountKey.present
          ? data.accountKey.value
          : this.accountKey,
      encryptedPayload: data.encryptedPayload.present
          ? data.encryptedPayload.value
          : this.encryptedPayload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EncryptedContactCacheRow(')
          ..write('accountKey: $accountKey, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountKey, encryptedPayload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EncryptedContactCacheRow &&
          other.accountKey == this.accountKey &&
          other.encryptedPayload == this.encryptedPayload &&
          other.updatedAt == this.updatedAt);
}

class EncryptedContactCacheRowsCompanion
    extends UpdateCompanion<EncryptedContactCacheRow> {
  final Value<String> accountKey;
  final Value<String> encryptedPayload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const EncryptedContactCacheRowsCompanion({
    this.accountKey = const Value.absent(),
    this.encryptedPayload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EncryptedContactCacheRowsCompanion.insert({
    required String accountKey,
    required String encryptedPayload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : accountKey = Value(accountKey),
       encryptedPayload = Value(encryptedPayload),
       updatedAt = Value(updatedAt);
  static Insertable<EncryptedContactCacheRow> custom({
    Expression<String>? accountKey,
    Expression<String>? encryptedPayload,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountKey != null) 'account_key': accountKey,
      if (encryptedPayload != null) 'encrypted_payload': encryptedPayload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EncryptedContactCacheRowsCompanion copyWith({
    Value<String>? accountKey,
    Value<String>? encryptedPayload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return EncryptedContactCacheRowsCompanion(
      accountKey: accountKey ?? this.accountKey,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountKey.present) {
      map['account_key'] = Variable<String>(accountKey.value);
    }
    if (encryptedPayload.present) {
      map['encrypted_payload'] = Variable<String>(encryptedPayload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EncryptedContactCacheRowsCompanion(')
          ..write('accountKey: $accountKey, ')
          ..write('encryptedPayload: $encryptedPayload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedContentRowsTable extends SavedContentRows
    with TableInfo<$SavedContentRowsTable, SavedContentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedContentRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _contentIdMeta = const VerificationMeta(
    'contentId',
  );
  @override
  late final GeneratedColumn<String> contentId = GeneratedColumn<String>(
    'content_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    contentId,
    contentType,
    deleted,
    updatedAt,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_content_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedContentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('content_id')) {
      context.handle(
        _contentIdMeta,
        contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentTypeMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {contentType, contentId};
  @override
  SavedContentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedContentRow(
      contentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_id'],
      )!,
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $SavedContentRowsTable createAlias(String alias) {
    return $SavedContentRowsTable(attachedDatabase, alias);
  }
}

class SavedContentRow extends DataClass implements Insertable<SavedContentRow> {
  final String contentId;
  final String contentType;
  final bool deleted;
  final DateTime updatedAt;
  final bool dirty;
  const SavedContentRow({
    required this.contentId,
    required this.contentType,
    required this.deleted,
    required this.updatedAt,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['content_id'] = Variable<String>(contentId);
    map['content_type'] = Variable<String>(contentType);
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  SavedContentRowsCompanion toCompanion(bool nullToAbsent) {
    return SavedContentRowsCompanion(
      contentId: Value(contentId),
      contentType: Value(contentType),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
      dirty: Value(dirty),
    );
  }

  factory SavedContentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedContentRow(
      contentId: serializer.fromJson<String>(json['contentId']),
      contentType: serializer.fromJson<String>(json['contentType']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'contentId': serializer.toJson<String>(contentId),
      'contentType': serializer.toJson<String>(contentType),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  SavedContentRow copyWith({
    String? contentId,
    String? contentType,
    bool? deleted,
    DateTime? updatedAt,
    bool? dirty,
  }) => SavedContentRow(
    contentId: contentId ?? this.contentId,
    contentType: contentType ?? this.contentType,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
    dirty: dirty ?? this.dirty,
  );
  SavedContentRow copyWithCompanion(SavedContentRowsCompanion data) {
    return SavedContentRow(
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedContentRow(')
          ..write('contentId: $contentId, ')
          ..write('contentType: $contentType, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(contentId, contentType, deleted, updatedAt, dirty);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedContentRow &&
          other.contentId == this.contentId &&
          other.contentType == this.contentType &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt &&
          other.dirty == this.dirty);
}

class SavedContentRowsCompanion extends UpdateCompanion<SavedContentRow> {
  final Value<String> contentId;
  final Value<String> contentType;
  final Value<bool> deleted;
  final Value<DateTime> updatedAt;
  final Value<bool> dirty;
  final Value<int> rowid;
  const SavedContentRowsCompanion({
    this.contentId = const Value.absent(),
    this.contentType = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedContentRowsCompanion.insert({
    required String contentId,
    required String contentType,
    this.deleted = const Value.absent(),
    required DateTime updatedAt,
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : contentId = Value(contentId),
       contentType = Value(contentType),
       updatedAt = Value(updatedAt);
  static Insertable<SavedContentRow> custom({
    Expression<String>? contentId,
    Expression<String>? contentType,
    Expression<bool>? deleted,
    Expression<DateTime>? updatedAt,
    Expression<bool>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (contentId != null) 'content_id': contentId,
      if (contentType != null) 'content_type': contentType,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedContentRowsCompanion copyWith({
    Value<String>? contentId,
    Value<String>? contentType,
    Value<bool>? deleted,
    Value<DateTime>? updatedAt,
    Value<bool>? dirty,
    Value<int>? rowid,
  }) {
    return SavedContentRowsCompanion(
      contentId: contentId ?? this.contentId,
      contentType: contentType ?? this.contentType,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (contentId.present) {
      map['content_id'] = Variable<String>(contentId.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedContentRowsCompanion(')
          ..write('contentId: $contentId, ')
          ..write('contentType: $contentType, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DraftRowsTable extends DraftRows
    with TableInfo<$DraftRowsTable, DraftRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DraftRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _draftTypeMeta = const VerificationMeta(
    'draftType',
  );
  @override
  late final GeneratedColumn<String> draftType = GeneratedColumn<String>(
    'draft_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonBodyMeta = const VerificationMeta(
    'jsonBody',
  );
  @override
  late final GeneratedColumn<String> jsonBody = GeneratedColumn<String>(
    'json_body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    draftType,
    jsonBody,
    deleted,
    updatedAt,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'draft_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<DraftRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('draft_type')) {
      context.handle(
        _draftTypeMeta,
        draftType.isAcceptableOrUnknown(data['draft_type']!, _draftTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_draftTypeMeta);
    }
    if (data.containsKey('json_body')) {
      context.handle(
        _jsonBodyMeta,
        jsonBody.isAcceptableOrUnknown(data['json_body']!, _jsonBodyMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonBodyMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DraftRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DraftRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      draftType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}draft_type'],
      )!,
      jsonBody: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json_body'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $DraftRowsTable createAlias(String alias) {
    return $DraftRowsTable(attachedDatabase, alias);
  }
}

class DraftRow extends DataClass implements Insertable<DraftRow> {
  final String id;
  final String draftType;
  final String jsonBody;
  final bool deleted;
  final DateTime updatedAt;
  final bool dirty;
  const DraftRow({
    required this.id,
    required this.draftType,
    required this.jsonBody,
    required this.deleted,
    required this.updatedAt,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['draft_type'] = Variable<String>(draftType);
    map['json_body'] = Variable<String>(jsonBody);
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  DraftRowsCompanion toCompanion(bool nullToAbsent) {
    return DraftRowsCompanion(
      id: Value(id),
      draftType: Value(draftType),
      jsonBody: Value(jsonBody),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
      dirty: Value(dirty),
    );
  }

  factory DraftRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DraftRow(
      id: serializer.fromJson<String>(json['id']),
      draftType: serializer.fromJson<String>(json['draftType']),
      jsonBody: serializer.fromJson<String>(json['jsonBody']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'draftType': serializer.toJson<String>(draftType),
      'jsonBody': serializer.toJson<String>(jsonBody),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  DraftRow copyWith({
    String? id,
    String? draftType,
    String? jsonBody,
    bool? deleted,
    DateTime? updatedAt,
    bool? dirty,
  }) => DraftRow(
    id: id ?? this.id,
    draftType: draftType ?? this.draftType,
    jsonBody: jsonBody ?? this.jsonBody,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
    dirty: dirty ?? this.dirty,
  );
  DraftRow copyWithCompanion(DraftRowsCompanion data) {
    return DraftRow(
      id: data.id.present ? data.id.value : this.id,
      draftType: data.draftType.present ? data.draftType.value : this.draftType,
      jsonBody: data.jsonBody.present ? data.jsonBody.value : this.jsonBody,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DraftRow(')
          ..write('id: $id, ')
          ..write('draftType: $draftType, ')
          ..write('jsonBody: $jsonBody, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, draftType, jsonBody, deleted, updatedAt, dirty);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DraftRow &&
          other.id == this.id &&
          other.draftType == this.draftType &&
          other.jsonBody == this.jsonBody &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt &&
          other.dirty == this.dirty);
}

class DraftRowsCompanion extends UpdateCompanion<DraftRow> {
  final Value<String> id;
  final Value<String> draftType;
  final Value<String> jsonBody;
  final Value<bool> deleted;
  final Value<DateTime> updatedAt;
  final Value<bool> dirty;
  final Value<int> rowid;
  const DraftRowsCompanion({
    this.id = const Value.absent(),
    this.draftType = const Value.absent(),
    this.jsonBody = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DraftRowsCompanion.insert({
    required String id,
    required String draftType,
    required String jsonBody,
    this.deleted = const Value.absent(),
    required DateTime updatedAt,
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       draftType = Value(draftType),
       jsonBody = Value(jsonBody),
       updatedAt = Value(updatedAt);
  static Insertable<DraftRow> custom({
    Expression<String>? id,
    Expression<String>? draftType,
    Expression<String>? jsonBody,
    Expression<bool>? deleted,
    Expression<DateTime>? updatedAt,
    Expression<bool>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (draftType != null) 'draft_type': draftType,
      if (jsonBody != null) 'json_body': jsonBody,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DraftRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? draftType,
    Value<String>? jsonBody,
    Value<bool>? deleted,
    Value<DateTime>? updatedAt,
    Value<bool>? dirty,
    Value<int>? rowid,
  }) {
    return DraftRowsCompanion(
      id: id ?? this.id,
      draftType: draftType ?? this.draftType,
      jsonBody: jsonBody ?? this.jsonBody,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (draftType.present) {
      map['draft_type'] = Variable<String>(draftType.value);
    }
    if (jsonBody.present) {
      map['json_body'] = Variable<String>(jsonBody.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DraftRowsCompanion(')
          ..write('id: $id, ')
          ..write('draftType: $draftType, ')
          ..write('jsonBody: $jsonBody, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$OfflineDatabase extends GeneratedDatabase {
  _$OfflineDatabase(QueryExecutor e) : super(e);
  $OfflineDatabaseManager get managers => $OfflineDatabaseManager(this);
  late final $OfflineContentRowsTable offlineContentRows =
      $OfflineContentRowsTable(this);
  late final $ContentSyncStatesTable contentSyncStates =
      $ContentSyncStatesTable(this);
  late final $OfflineAlertQueueRowsTable offlineAlertQueueRows =
      $OfflineAlertQueueRowsTable(this);
  late final $EncryptedContactCacheRowsTable encryptedContactCacheRows =
      $EncryptedContactCacheRowsTable(this);
  late final $SavedContentRowsTable savedContentRows = $SavedContentRowsTable(
    this,
  );
  late final $DraftRowsTable draftRows = $DraftRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    offlineContentRows,
    contentSyncStates,
    offlineAlertQueueRows,
    encryptedContactCacheRows,
    savedContentRows,
    draftRows,
  ];
}

typedef $$OfflineContentRowsTableCreateCompanionBuilder =
    OfflineContentRowsCompanion Function({
      required String id,
      required String layer,
      required String jurisdiction,
      required String recordType,
      required String jsonBody,
      required int contentVersion,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$OfflineContentRowsTableUpdateCompanionBuilder =
    OfflineContentRowsCompanion Function({
      Value<String> id,
      Value<String> layer,
      Value<String> jurisdiction,
      Value<String> recordType,
      Value<String> jsonBody,
      Value<int> contentVersion,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$OfflineContentRowsTableFilterComposer
    extends Composer<_$OfflineDatabase, $OfflineContentRowsTable> {
  $$OfflineContentRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jurisdiction => $composableBuilder(
    column: $table.jurisdiction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsonBody => $composableBuilder(
    column: $table.jsonBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineContentRowsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $OfflineContentRowsTable> {
  $$OfflineContentRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jurisdiction => $composableBuilder(
    column: $table.jurisdiction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsonBody => $composableBuilder(
    column: $table.jsonBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineContentRowsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $OfflineContentRowsTable> {
  $$OfflineContentRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get layer =>
      $composableBuilder(column: $table.layer, builder: (column) => column);

  GeneratedColumn<String> get jurisdiction => $composableBuilder(
    column: $table.jurisdiction,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordType => $composableBuilder(
    column: $table.recordType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jsonBody =>
      $composableBuilder(column: $table.jsonBody, builder: (column) => column);

  GeneratedColumn<int> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OfflineContentRowsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $OfflineContentRowsTable,
          OfflineContentRow,
          $$OfflineContentRowsTableFilterComposer,
          $$OfflineContentRowsTableOrderingComposer,
          $$OfflineContentRowsTableAnnotationComposer,
          $$OfflineContentRowsTableCreateCompanionBuilder,
          $$OfflineContentRowsTableUpdateCompanionBuilder,
          (
            OfflineContentRow,
            BaseReferences<
              _$OfflineDatabase,
              $OfflineContentRowsTable,
              OfflineContentRow
            >,
          ),
          OfflineContentRow,
          PrefetchHooks Function()
        > {
  $$OfflineContentRowsTableTableManager(
    _$OfflineDatabase db,
    $OfflineContentRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineContentRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineContentRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineContentRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> layer = const Value.absent(),
                Value<String> jurisdiction = const Value.absent(),
                Value<String> recordType = const Value.absent(),
                Value<String> jsonBody = const Value.absent(),
                Value<int> contentVersion = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineContentRowsCompanion(
                id: id,
                layer: layer,
                jurisdiction: jurisdiction,
                recordType: recordType,
                jsonBody: jsonBody,
                contentVersion: contentVersion,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String layer,
                required String jurisdiction,
                required String recordType,
                required String jsonBody,
                required int contentVersion,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => OfflineContentRowsCompanion.insert(
                id: id,
                layer: layer,
                jurisdiction: jurisdiction,
                recordType: recordType,
                jsonBody: jsonBody,
                contentVersion: contentVersion,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineContentRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $OfflineContentRowsTable,
      OfflineContentRow,
      $$OfflineContentRowsTableFilterComposer,
      $$OfflineContentRowsTableOrderingComposer,
      $$OfflineContentRowsTableAnnotationComposer,
      $$OfflineContentRowsTableCreateCompanionBuilder,
      $$OfflineContentRowsTableUpdateCompanionBuilder,
      (
        OfflineContentRow,
        BaseReferences<
          _$OfflineDatabase,
          $OfflineContentRowsTable,
          OfflineContentRow
        >,
      ),
      OfflineContentRow,
      PrefetchHooks Function()
    >;
typedef $$ContentSyncStatesTableCreateCompanionBuilder =
    ContentSyncStatesCompanion Function({
      required String layer,
      required String jurisdiction,
      Value<int> contentVersion,
      Value<String?> etag,
      Value<String?> checksum,
      Value<String?> keyId,
      Value<DateTime?> lastCheckedAt,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$ContentSyncStatesTableUpdateCompanionBuilder =
    ContentSyncStatesCompanion Function({
      Value<String> layer,
      Value<String> jurisdiction,
      Value<int> contentVersion,
      Value<String?> etag,
      Value<String?> checksum,
      Value<String?> keyId,
      Value<DateTime?> lastCheckedAt,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$ContentSyncStatesTableFilterComposer
    extends Composer<_$OfflineDatabase, $ContentSyncStatesTable> {
  $$ContentSyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jurisdiction => $composableBuilder(
    column: $table.jurisdiction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyId => $composableBuilder(
    column: $table.keyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentSyncStatesTableOrderingComposer
    extends Composer<_$OfflineDatabase, $ContentSyncStatesTable> {
  $$ContentSyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get layer => $composableBuilder(
    column: $table.layer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jurisdiction => $composableBuilder(
    column: $table.jurisdiction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyId => $composableBuilder(
    column: $table.keyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentSyncStatesTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $ContentSyncStatesTable> {
  $$ContentSyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get layer =>
      $composableBuilder(column: $table.layer, builder: (column) => column);

  GeneratedColumn<String> get jurisdiction => $composableBuilder(
    column: $table.jurisdiction,
    builder: (column) => column,
  );

  GeneratedColumn<int> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<String> get keyId =>
      $composableBuilder(column: $table.keyId, builder: (column) => column);

  GeneratedColumn<DateTime> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$ContentSyncStatesTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $ContentSyncStatesTable,
          ContentSyncState,
          $$ContentSyncStatesTableFilterComposer,
          $$ContentSyncStatesTableOrderingComposer,
          $$ContentSyncStatesTableAnnotationComposer,
          $$ContentSyncStatesTableCreateCompanionBuilder,
          $$ContentSyncStatesTableUpdateCompanionBuilder,
          (
            ContentSyncState,
            BaseReferences<
              _$OfflineDatabase,
              $ContentSyncStatesTable,
              ContentSyncState
            >,
          ),
          ContentSyncState,
          PrefetchHooks Function()
        > {
  $$ContentSyncStatesTableTableManager(
    _$OfflineDatabase db,
    $ContentSyncStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentSyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentSyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentSyncStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> layer = const Value.absent(),
                Value<String> jurisdiction = const Value.absent(),
                Value<int> contentVersion = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                Value<String?> keyId = const Value.absent(),
                Value<DateTime?> lastCheckedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentSyncStatesCompanion(
                layer: layer,
                jurisdiction: jurisdiction,
                contentVersion: contentVersion,
                etag: etag,
                checksum: checksum,
                keyId: keyId,
                lastCheckedAt: lastCheckedAt,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String layer,
                required String jurisdiction,
                Value<int> contentVersion = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                Value<String?> keyId = const Value.absent(),
                Value<DateTime?> lastCheckedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentSyncStatesCompanion.insert(
                layer: layer,
                jurisdiction: jurisdiction,
                contentVersion: contentVersion,
                etag: etag,
                checksum: checksum,
                keyId: keyId,
                lastCheckedAt: lastCheckedAt,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentSyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $ContentSyncStatesTable,
      ContentSyncState,
      $$ContentSyncStatesTableFilterComposer,
      $$ContentSyncStatesTableOrderingComposer,
      $$ContentSyncStatesTableAnnotationComposer,
      $$ContentSyncStatesTableCreateCompanionBuilder,
      $$ContentSyncStatesTableUpdateCompanionBuilder,
      (
        ContentSyncState,
        BaseReferences<
          _$OfflineDatabase,
          $ContentSyncStatesTable,
          ContentSyncState
        >,
      ),
      ContentSyncState,
      PrefetchHooks Function()
    >;
typedef $$OfflineAlertQueueRowsTableCreateCompanionBuilder =
    OfflineAlertQueueRowsCompanion Function({
      required String idempotencyKey,
      required String jsonBody,
      Value<int> attempts,
      required DateTime createdAt,
      required DateTime nextAttemptAt,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$OfflineAlertQueueRowsTableUpdateCompanionBuilder =
    OfflineAlertQueueRowsCompanion Function({
      Value<String> idempotencyKey,
      Value<String> jsonBody,
      Value<int> attempts,
      Value<DateTime> createdAt,
      Value<DateTime> nextAttemptAt,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$OfflineAlertQueueRowsTableFilterComposer
    extends Composer<_$OfflineDatabase, $OfflineAlertQueueRowsTable> {
  $$OfflineAlertQueueRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsonBody => $composableBuilder(
    column: $table.jsonBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineAlertQueueRowsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $OfflineAlertQueueRowsTable> {
  $$OfflineAlertQueueRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsonBody => $composableBuilder(
    column: $table.jsonBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineAlertQueueRowsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $OfflineAlertQueueRowsTable> {
  $$OfflineAlertQueueRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jsonBody =>
      $composableBuilder(column: $table.jsonBody, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$OfflineAlertQueueRowsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $OfflineAlertQueueRowsTable,
          OfflineAlertQueueRow,
          $$OfflineAlertQueueRowsTableFilterComposer,
          $$OfflineAlertQueueRowsTableOrderingComposer,
          $$OfflineAlertQueueRowsTableAnnotationComposer,
          $$OfflineAlertQueueRowsTableCreateCompanionBuilder,
          $$OfflineAlertQueueRowsTableUpdateCompanionBuilder,
          (
            OfflineAlertQueueRow,
            BaseReferences<
              _$OfflineDatabase,
              $OfflineAlertQueueRowsTable,
              OfflineAlertQueueRow
            >,
          ),
          OfflineAlertQueueRow,
          PrefetchHooks Function()
        > {
  $$OfflineAlertQueueRowsTableTableManager(
    _$OfflineDatabase db,
    $OfflineAlertQueueRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineAlertQueueRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$OfflineAlertQueueRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OfflineAlertQueueRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> jsonBody = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> nextAttemptAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineAlertQueueRowsCompanion(
                idempotencyKey: idempotencyKey,
                jsonBody: jsonBody,
                attempts: attempts,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String idempotencyKey,
                required String jsonBody,
                Value<int> attempts = const Value.absent(),
                required DateTime createdAt,
                required DateTime nextAttemptAt,
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OfflineAlertQueueRowsCompanion.insert(
                idempotencyKey: idempotencyKey,
                jsonBody: jsonBody,
                attempts: attempts,
                createdAt: createdAt,
                nextAttemptAt: nextAttemptAt,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineAlertQueueRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $OfflineAlertQueueRowsTable,
      OfflineAlertQueueRow,
      $$OfflineAlertQueueRowsTableFilterComposer,
      $$OfflineAlertQueueRowsTableOrderingComposer,
      $$OfflineAlertQueueRowsTableAnnotationComposer,
      $$OfflineAlertQueueRowsTableCreateCompanionBuilder,
      $$OfflineAlertQueueRowsTableUpdateCompanionBuilder,
      (
        OfflineAlertQueueRow,
        BaseReferences<
          _$OfflineDatabase,
          $OfflineAlertQueueRowsTable,
          OfflineAlertQueueRow
        >,
      ),
      OfflineAlertQueueRow,
      PrefetchHooks Function()
    >;
typedef $$EncryptedContactCacheRowsTableCreateCompanionBuilder =
    EncryptedContactCacheRowsCompanion Function({
      required String accountKey,
      required String encryptedPayload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$EncryptedContactCacheRowsTableUpdateCompanionBuilder =
    EncryptedContactCacheRowsCompanion Function({
      Value<String> accountKey,
      Value<String> encryptedPayload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$EncryptedContactCacheRowsTableFilterComposer
    extends Composer<_$OfflineDatabase, $EncryptedContactCacheRowsTable> {
  $$EncryptedContactCacheRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EncryptedContactCacheRowsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $EncryptedContactCacheRowsTable> {
  $$EncryptedContactCacheRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EncryptedContactCacheRowsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $EncryptedContactCacheRowsTable> {
  $$EncryptedContactCacheRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get accountKey => $composableBuilder(
    column: $table.accountKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedPayload => $composableBuilder(
    column: $table.encryptedPayload,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$EncryptedContactCacheRowsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $EncryptedContactCacheRowsTable,
          EncryptedContactCacheRow,
          $$EncryptedContactCacheRowsTableFilterComposer,
          $$EncryptedContactCacheRowsTableOrderingComposer,
          $$EncryptedContactCacheRowsTableAnnotationComposer,
          $$EncryptedContactCacheRowsTableCreateCompanionBuilder,
          $$EncryptedContactCacheRowsTableUpdateCompanionBuilder,
          (
            EncryptedContactCacheRow,
            BaseReferences<
              _$OfflineDatabase,
              $EncryptedContactCacheRowsTable,
              EncryptedContactCacheRow
            >,
          ),
          EncryptedContactCacheRow,
          PrefetchHooks Function()
        > {
  $$EncryptedContactCacheRowsTableTableManager(
    _$OfflineDatabase db,
    $EncryptedContactCacheRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EncryptedContactCacheRowsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$EncryptedContactCacheRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EncryptedContactCacheRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> accountKey = const Value.absent(),
                Value<String> encryptedPayload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EncryptedContactCacheRowsCompanion(
                accountKey: accountKey,
                encryptedPayload: encryptedPayload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountKey,
                required String encryptedPayload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EncryptedContactCacheRowsCompanion.insert(
                accountKey: accountKey,
                encryptedPayload: encryptedPayload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EncryptedContactCacheRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $EncryptedContactCacheRowsTable,
      EncryptedContactCacheRow,
      $$EncryptedContactCacheRowsTableFilterComposer,
      $$EncryptedContactCacheRowsTableOrderingComposer,
      $$EncryptedContactCacheRowsTableAnnotationComposer,
      $$EncryptedContactCacheRowsTableCreateCompanionBuilder,
      $$EncryptedContactCacheRowsTableUpdateCompanionBuilder,
      (
        EncryptedContactCacheRow,
        BaseReferences<
          _$OfflineDatabase,
          $EncryptedContactCacheRowsTable,
          EncryptedContactCacheRow
        >,
      ),
      EncryptedContactCacheRow,
      PrefetchHooks Function()
    >;
typedef $$SavedContentRowsTableCreateCompanionBuilder =
    SavedContentRowsCompanion Function({
      required String contentId,
      required String contentType,
      Value<bool> deleted,
      required DateTime updatedAt,
      Value<bool> dirty,
      Value<int> rowid,
    });
typedef $$SavedContentRowsTableUpdateCompanionBuilder =
    SavedContentRowsCompanion Function({
      Value<String> contentId,
      Value<String> contentType,
      Value<bool> deleted,
      Value<DateTime> updatedAt,
      Value<bool> dirty,
      Value<int> rowid,
    });

class $$SavedContentRowsTableFilterComposer
    extends Composer<_$OfflineDatabase, $SavedContentRowsTable> {
  $$SavedContentRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedContentRowsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $SavedContentRowsTable> {
  $$SavedContentRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get contentId => $composableBuilder(
    column: $table.contentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedContentRowsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $SavedContentRowsTable> {
  $$SavedContentRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get contentId =>
      $composableBuilder(column: $table.contentId, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$SavedContentRowsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $SavedContentRowsTable,
          SavedContentRow,
          $$SavedContentRowsTableFilterComposer,
          $$SavedContentRowsTableOrderingComposer,
          $$SavedContentRowsTableAnnotationComposer,
          $$SavedContentRowsTableCreateCompanionBuilder,
          $$SavedContentRowsTableUpdateCompanionBuilder,
          (
            SavedContentRow,
            BaseReferences<
              _$OfflineDatabase,
              $SavedContentRowsTable,
              SavedContentRow
            >,
          ),
          SavedContentRow,
          PrefetchHooks Function()
        > {
  $$SavedContentRowsTableTableManager(
    _$OfflineDatabase db,
    $SavedContentRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SavedContentRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SavedContentRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SavedContentRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> contentId = const Value.absent(),
                Value<String> contentType = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedContentRowsCompanion(
                contentId: contentId,
                contentType: contentType,
                deleted: deleted,
                updatedAt: updatedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String contentId,
                required String contentType,
                Value<bool> deleted = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedContentRowsCompanion.insert(
                contentId: contentId,
                contentType: contentType,
                deleted: deleted,
                updatedAt: updatedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedContentRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $SavedContentRowsTable,
      SavedContentRow,
      $$SavedContentRowsTableFilterComposer,
      $$SavedContentRowsTableOrderingComposer,
      $$SavedContentRowsTableAnnotationComposer,
      $$SavedContentRowsTableCreateCompanionBuilder,
      $$SavedContentRowsTableUpdateCompanionBuilder,
      (
        SavedContentRow,
        BaseReferences<
          _$OfflineDatabase,
          $SavedContentRowsTable,
          SavedContentRow
        >,
      ),
      SavedContentRow,
      PrefetchHooks Function()
    >;
typedef $$DraftRowsTableCreateCompanionBuilder =
    DraftRowsCompanion Function({
      required String id,
      required String draftType,
      required String jsonBody,
      Value<bool> deleted,
      required DateTime updatedAt,
      Value<bool> dirty,
      Value<int> rowid,
    });
typedef $$DraftRowsTableUpdateCompanionBuilder =
    DraftRowsCompanion Function({
      Value<String> id,
      Value<String> draftType,
      Value<String> jsonBody,
      Value<bool> deleted,
      Value<DateTime> updatedAt,
      Value<bool> dirty,
      Value<int> rowid,
    });

class $$DraftRowsTableFilterComposer
    extends Composer<_$OfflineDatabase, $DraftRowsTable> {
  $$DraftRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get draftType => $composableBuilder(
    column: $table.draftType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jsonBody => $composableBuilder(
    column: $table.jsonBody,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DraftRowsTableOrderingComposer
    extends Composer<_$OfflineDatabase, $DraftRowsTable> {
  $$DraftRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get draftType => $composableBuilder(
    column: $table.draftType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jsonBody => $composableBuilder(
    column: $table.jsonBody,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DraftRowsTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $DraftRowsTable> {
  $$DraftRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get draftType =>
      $composableBuilder(column: $table.draftType, builder: (column) => column);

  GeneratedColumn<String> get jsonBody =>
      $composableBuilder(column: $table.jsonBody, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$DraftRowsTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $DraftRowsTable,
          DraftRow,
          $$DraftRowsTableFilterComposer,
          $$DraftRowsTableOrderingComposer,
          $$DraftRowsTableAnnotationComposer,
          $$DraftRowsTableCreateCompanionBuilder,
          $$DraftRowsTableUpdateCompanionBuilder,
          (
            DraftRow,
            BaseReferences<_$OfflineDatabase, $DraftRowsTable, DraftRow>,
          ),
          DraftRow,
          PrefetchHooks Function()
        > {
  $$DraftRowsTableTableManager(_$OfflineDatabase db, $DraftRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DraftRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DraftRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DraftRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> draftType = const Value.absent(),
                Value<String> jsonBody = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftRowsCompanion(
                id: id,
                draftType: draftType,
                jsonBody: jsonBody,
                deleted: deleted,
                updatedAt: updatedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String draftType,
                required String jsonBody,
                Value<bool> deleted = const Value.absent(),
                required DateTime updatedAt,
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DraftRowsCompanion.insert(
                id: id,
                draftType: draftType,
                jsonBody: jsonBody,
                deleted: deleted,
                updatedAt: updatedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DraftRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $DraftRowsTable,
      DraftRow,
      $$DraftRowsTableFilterComposer,
      $$DraftRowsTableOrderingComposer,
      $$DraftRowsTableAnnotationComposer,
      $$DraftRowsTableCreateCompanionBuilder,
      $$DraftRowsTableUpdateCompanionBuilder,
      (DraftRow, BaseReferences<_$OfflineDatabase, $DraftRowsTable, DraftRow>),
      DraftRow,
      PrefetchHooks Function()
    >;

class $OfflineDatabaseManager {
  final _$OfflineDatabase _db;
  $OfflineDatabaseManager(this._db);
  $$OfflineContentRowsTableTableManager get offlineContentRows =>
      $$OfflineContentRowsTableTableManager(_db, _db.offlineContentRows);
  $$ContentSyncStatesTableTableManager get contentSyncStates =>
      $$ContentSyncStatesTableTableManager(_db, _db.contentSyncStates);
  $$OfflineAlertQueueRowsTableTableManager get offlineAlertQueueRows =>
      $$OfflineAlertQueueRowsTableTableManager(_db, _db.offlineAlertQueueRows);
  $$EncryptedContactCacheRowsTableTableManager get encryptedContactCacheRows =>
      $$EncryptedContactCacheRowsTableTableManager(
        _db,
        _db.encryptedContactCacheRows,
      );
  $$SavedContentRowsTableTableManager get savedContentRows =>
      $$SavedContentRowsTableTableManager(_db, _db.savedContentRows);
  $$DraftRowsTableTableManager get draftRows =>
      $$DraftRowsTableTableManager(_db, _db.draftRows);
}
