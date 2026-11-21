// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AccountsTableTable extends AccountsTable
    with TableInfo<$AccountsTableTable, AccountEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
      'email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _providerMeta =
      const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
      'provider', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _avatarColorValueMeta =
      const VerificationMeta('avatarColorValue');
  @override
  late final GeneratedColumn<int> avatarColorValue = GeneratedColumn<int>(
      'avatar_color_value', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _lastSyncedAtMeta =
      const VerificationMeta('lastSyncedAt');
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
      'last_synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _totalMessagesMeta =
      const VerificationMeta('totalMessages');
  @override
  late final GeneratedColumn<int> totalMessages = GeneratedColumn<int>(
      'total_messages', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        email,
        displayName,
        provider,
        avatarColorValue,
        lastSyncedAt,
        totalMessages
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts_table';
  @override
  VerificationContext validateIntegrity(Insertable<AccountEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
          _emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(_providerMeta,
          provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('avatar_color_value')) {
      context.handle(
          _avatarColorValueMeta,
          avatarColorValue.isAcceptableOrUnknown(
              data['avatar_color_value']!, _avatarColorValueMeta));
    } else if (isInserting) {
      context.missing(_avatarColorValueMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
          _lastSyncedAtMeta,
          lastSyncedAt.isAcceptableOrUnknown(
              data['last_synced_at']!, _lastSyncedAtMeta));
    }
    if (data.containsKey('total_messages')) {
      context.handle(
          _totalMessagesMeta,
          totalMessages.isAcceptableOrUnknown(
              data['total_messages']!, _totalMessagesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      email: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}email'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      provider: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      avatarColorValue: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}avatar_color_value'])!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_synced_at']),
      totalMessages: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_messages'])!,
    );
  }

  @override
  $AccountsTableTable createAlias(String alias) {
    return $AccountsTableTable(attachedDatabase, alias);
  }
}

class AccountEntry extends DataClass implements Insertable<AccountEntry> {
  final String id;
  final String email;
  final String displayName;
  final String provider;
  final int avatarColorValue;
  final DateTime? lastSyncedAt;
  final int totalMessages;
  const AccountEntry(
      {required this.id,
      required this.email,
      required this.displayName,
      required this.provider,
      required this.avatarColorValue,
      this.lastSyncedAt,
      required this.totalMessages});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['email'] = Variable<String>(email);
    map['display_name'] = Variable<String>(displayName);
    map['provider'] = Variable<String>(provider);
    map['avatar_color_value'] = Variable<int>(avatarColorValue);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['total_messages'] = Variable<int>(totalMessages);
    return map;
  }

  AccountsTableCompanion toCompanion(bool nullToAbsent) {
    return AccountsTableCompanion(
      id: Value(id),
      email: Value(email),
      displayName: Value(displayName),
      provider: Value(provider),
      avatarColorValue: Value(avatarColorValue),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      totalMessages: Value(totalMessages),
    );
  }

  factory AccountEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountEntry(
      id: serializer.fromJson<String>(json['id']),
      email: serializer.fromJson<String>(json['email']),
      displayName: serializer.fromJson<String>(json['displayName']),
      provider: serializer.fromJson<String>(json['provider']),
      avatarColorValue: serializer.fromJson<int>(json['avatarColorValue']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      totalMessages: serializer.fromJson<int>(json['totalMessages']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'email': serializer.toJson<String>(email),
      'displayName': serializer.toJson<String>(displayName),
      'provider': serializer.toJson<String>(provider),
      'avatarColorValue': serializer.toJson<int>(avatarColorValue),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'totalMessages': serializer.toJson<int>(totalMessages),
    };
  }

  AccountEntry copyWith(
          {String? id,
          String? email,
          String? displayName,
          String? provider,
          int? avatarColorValue,
          Value<DateTime?> lastSyncedAt = const Value.absent(),
          int? totalMessages}) =>
      AccountEntry(
        id: id ?? this.id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        provider: provider ?? this.provider,
        avatarColorValue: avatarColorValue ?? this.avatarColorValue,
        lastSyncedAt:
            lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
        totalMessages: totalMessages ?? this.totalMessages,
      );
  AccountEntry copyWithCompanion(AccountsTableCompanion data) {
    return AccountEntry(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      provider: data.provider.present ? data.provider.value : this.provider,
      avatarColorValue: data.avatarColorValue.present
          ? data.avatarColorValue.value
          : this.avatarColorValue,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      totalMessages: data.totalMessages.present
          ? data.totalMessages.value
          : this.totalMessages,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountEntry(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('provider: $provider, ')
          ..write('avatarColorValue: $avatarColorValue, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('totalMessages: $totalMessages')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, email, displayName, provider,
      avatarColorValue, lastSyncedAt, totalMessages);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountEntry &&
          other.id == this.id &&
          other.email == this.email &&
          other.displayName == this.displayName &&
          other.provider == this.provider &&
          other.avatarColorValue == this.avatarColorValue &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.totalMessages == this.totalMessages);
}

class AccountsTableCompanion extends UpdateCompanion<AccountEntry> {
  final Value<String> id;
  final Value<String> email;
  final Value<String> displayName;
  final Value<String> provider;
  final Value<int> avatarColorValue;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> totalMessages;
  final Value<int> rowid;
  const AccountsTableCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.displayName = const Value.absent(),
    this.provider = const Value.absent(),
    this.avatarColorValue = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.totalMessages = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsTableCompanion.insert({
    required String id,
    required String email,
    required String displayName,
    required String provider,
    required int avatarColorValue,
    this.lastSyncedAt = const Value.absent(),
    this.totalMessages = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        email = Value(email),
        displayName = Value(displayName),
        provider = Value(provider),
        avatarColorValue = Value(avatarColorValue);
  static Insertable<AccountEntry> custom({
    Expression<String>? id,
    Expression<String>? email,
    Expression<String>? displayName,
    Expression<String>? provider,
    Expression<int>? avatarColorValue,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? totalMessages,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (displayName != null) 'display_name': displayName,
      if (provider != null) 'provider': provider,
      if (avatarColorValue != null) 'avatar_color_value': avatarColorValue,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (totalMessages != null) 'total_messages': totalMessages,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? email,
      Value<String>? displayName,
      Value<String>? provider,
      Value<int>? avatarColorValue,
      Value<DateTime?>? lastSyncedAt,
      Value<int>? totalMessages,
      Value<int>? rowid}) {
    return AccountsTableCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      provider: provider ?? this.provider,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      totalMessages: totalMessages ?? this.totalMessages,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (avatarColorValue.present) {
      map['avatar_color_value'] = Variable<int>(avatarColorValue.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (totalMessages.present) {
      map['total_messages'] = Variable<int>(totalMessages.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsTableCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('displayName: $displayName, ')
          ..write('provider: $provider, ')
          ..write('avatarColorValue: $avatarColorValue, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('totalMessages: $totalMessages, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTableTable extends MessagesTable
    with TableInfo<$MessagesTableTable, MessageEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
      'account_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _remoteMessageIdMeta =
      const VerificationMeta('remoteMessageId');
  @override
  late final GeneratedColumn<String> remoteMessageId = GeneratedColumn<String>(
      'remote_message_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _threadIdMeta =
      const VerificationMeta('threadId');
  @override
  late final GeneratedColumn<String> threadId = GeneratedColumn<String>(
      'thread_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _senderEmailMeta =
      const VerificationMeta('senderEmail');
  @override
  late final GeneratedColumn<String> senderEmail = GeneratedColumn<String>(
      'sender_email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderNameMeta =
      const VerificationMeta('senderName');
  @override
  late final GeneratedColumn<String> senderName = GeneratedColumn<String>(
      'sender_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subjectMeta =
      const VerificationMeta('subject');
  @override
  late final GeneratedColumn<String> subject = GeneratedColumn<String>(
      'subject', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _snippetMeta =
      const VerificationMeta('snippet');
  @override
  late final GeneratedColumn<String> snippet = GeneratedColumn<String>(
      'snippet', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _plainTextBodyMeta =
      const VerificationMeta('plainTextBody');
  @override
  late final GeneratedColumn<String> plainTextBody = GeneratedColumn<String>(
      'plain_text_body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _customTagMeta =
      const VerificationMeta('customTag');
  @override
  late final GeneratedColumn<String> customTag = GeneratedColumn<String>(
      'custom_tag', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _unsubscribeUrlMeta =
      const VerificationMeta('unsubscribeUrl');
  @override
  late final GeneratedColumn<String> unsubscribeUrl = GeneratedColumn<String>(
      'unsubscribe_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _unsubscribeMailtoMeta =
      const VerificationMeta('unsubscribeMailto');
  @override
  late final GeneratedColumn<String> unsubscribeMailto =
      GeneratedColumn<String>('unsubscribe_mailto', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isReadMeta = const VerificationMeta('isRead');
  @override
  late final GeneratedColumn<bool> isRead = GeneratedColumn<bool>(
      'is_read', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_read" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isArchivedMeta =
      const VerificationMeta('isArchived');
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
      'is_archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isStarredMeta =
      const VerificationMeta('isStarred');
  @override
  late final GeneratedColumn<bool> isStarred = GeneratedColumn<bool>(
      'is_starred', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_starred" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isLockedMeta =
      const VerificationMeta('isLocked');
  @override
  late final GeneratedColumn<bool> isLocked = GeneratedColumn<bool>(
      'is_locked', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_locked" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _receivedAtMeta =
      const VerificationMeta('receivedAt');
  @override
  late final GeneratedColumn<DateTime> receivedAt = GeneratedColumn<DateTime>(
      'received_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        accountId,
        remoteMessageId,
        threadId,
        senderEmail,
        senderName,
        subject,
        snippet,
        plainTextBody,
        category,
        customTag,
        unsubscribeUrl,
        unsubscribeMailto,
        isRead,
        isArchived,
        isStarred,
        isLocked,
        receivedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages_table';
  @override
  VerificationContext validateIntegrity(Insertable<MessageEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('remote_message_id')) {
      context.handle(
          _remoteMessageIdMeta,
          remoteMessageId.isAcceptableOrUnknown(
              data['remote_message_id']!, _remoteMessageIdMeta));
    } else if (isInserting) {
      context.missing(_remoteMessageIdMeta);
    }
    if (data.containsKey('thread_id')) {
      context.handle(_threadIdMeta,
          threadId.isAcceptableOrUnknown(data['thread_id']!, _threadIdMeta));
    }
    if (data.containsKey('sender_email')) {
      context.handle(
          _senderEmailMeta,
          senderEmail.isAcceptableOrUnknown(
              data['sender_email']!, _senderEmailMeta));
    } else if (isInserting) {
      context.missing(_senderEmailMeta);
    }
    if (data.containsKey('sender_name')) {
      context.handle(
          _senderNameMeta,
          senderName.isAcceptableOrUnknown(
              data['sender_name']!, _senderNameMeta));
    } else if (isInserting) {
      context.missing(_senderNameMeta);
    }
    if (data.containsKey('subject')) {
      context.handle(_subjectMeta,
          subject.isAcceptableOrUnknown(data['subject']!, _subjectMeta));
    } else if (isInserting) {
      context.missing(_subjectMeta);
    }
    if (data.containsKey('snippet')) {
      context.handle(_snippetMeta,
          snippet.isAcceptableOrUnknown(data['snippet']!, _snippetMeta));
    } else if (isInserting) {
      context.missing(_snippetMeta);
    }
    if (data.containsKey('plain_text_body')) {
      context.handle(
          _plainTextBodyMeta,
          plainTextBody.isAcceptableOrUnknown(
              data['plain_text_body']!, _plainTextBodyMeta));
    } else if (isInserting) {
      context.missing(_plainTextBodyMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('custom_tag')) {
      context.handle(_customTagMeta,
          customTag.isAcceptableOrUnknown(data['custom_tag']!, _customTagMeta));
    }
    if (data.containsKey('unsubscribe_url')) {
      context.handle(
          _unsubscribeUrlMeta,
          unsubscribeUrl.isAcceptableOrUnknown(
              data['unsubscribe_url']!, _unsubscribeUrlMeta));
    }
    if (data.containsKey('unsubscribe_mailto')) {
      context.handle(
          _unsubscribeMailtoMeta,
          unsubscribeMailto.isAcceptableOrUnknown(
              data['unsubscribe_mailto']!, _unsubscribeMailtoMeta));
    }
    if (data.containsKey('is_read')) {
      context.handle(_isReadMeta,
          isRead.isAcceptableOrUnknown(data['is_read']!, _isReadMeta));
    }
    if (data.containsKey('is_archived')) {
      context.handle(
          _isArchivedMeta,
          isArchived.isAcceptableOrUnknown(
              data['is_archived']!, _isArchivedMeta));
    }
    if (data.containsKey('is_starred')) {
      context.handle(_isStarredMeta,
          isStarred.isAcceptableOrUnknown(data['is_starred']!, _isStarredMeta));
    }
    if (data.containsKey('is_locked')) {
      context.handle(_isLockedMeta,
          isLocked.isAcceptableOrUnknown(data['is_locked']!, _isLockedMeta));
    }
    if (data.containsKey('received_at')) {
      context.handle(
          _receivedAtMeta,
          receivedAt.isAcceptableOrUnknown(
              data['received_at']!, _receivedAtMeta));
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_id'])!,
      remoteMessageId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}remote_message_id'])!,
      threadId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thread_id']),
      senderEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_email'])!,
      senderName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_name'])!,
      subject: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject'])!,
      snippet: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}snippet'])!,
      plainTextBody: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}plain_text_body'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      customTag: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}custom_tag']),
      unsubscribeUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unsubscribe_url']),
      unsubscribeMailto: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}unsubscribe_mailto']),
      isRead: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_read'])!,
      isArchived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_archived'])!,
      isStarred: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_starred'])!,
      isLocked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_locked'])!,
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}received_at'])!,
    );
  }

  @override
  $MessagesTableTable createAlias(String alias) {
    return $MessagesTableTable(attachedDatabase, alias);
  }
}

class MessageEntry extends DataClass implements Insertable<MessageEntry> {
  final String id;
  final String accountId;
  final String remoteMessageId;
  final String? threadId;
  final String senderEmail;
  final String senderName;
  final String subject;
  final String snippet;
  final String plainTextBody;
  final String category;
  final String? customTag;
  final String? unsubscribeUrl;
  final String? unsubscribeMailto;
  final bool isRead;
  final bool isArchived;
  final bool isStarred;
  final bool isLocked;
  final DateTime receivedAt;
  const MessageEntry(
      {required this.id,
      required this.accountId,
      required this.remoteMessageId,
      this.threadId,
      required this.senderEmail,
      required this.senderName,
      required this.subject,
      required this.snippet,
      required this.plainTextBody,
      required this.category,
      this.customTag,
      this.unsubscribeUrl,
      this.unsubscribeMailto,
      required this.isRead,
      required this.isArchived,
      required this.isStarred,
      required this.isLocked,
      required this.receivedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['remote_message_id'] = Variable<String>(remoteMessageId);
    if (!nullToAbsent || threadId != null) {
      map['thread_id'] = Variable<String>(threadId);
    }
    map['sender_email'] = Variable<String>(senderEmail);
    map['sender_name'] = Variable<String>(senderName);
    map['subject'] = Variable<String>(subject);
    map['snippet'] = Variable<String>(snippet);
    map['plain_text_body'] = Variable<String>(plainTextBody);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || customTag != null) {
      map['custom_tag'] = Variable<String>(customTag);
    }
    if (!nullToAbsent || unsubscribeUrl != null) {
      map['unsubscribe_url'] = Variable<String>(unsubscribeUrl);
    }
    if (!nullToAbsent || unsubscribeMailto != null) {
      map['unsubscribe_mailto'] = Variable<String>(unsubscribeMailto);
    }
    map['is_read'] = Variable<bool>(isRead);
    map['is_archived'] = Variable<bool>(isArchived);
    map['is_starred'] = Variable<bool>(isStarred);
    map['is_locked'] = Variable<bool>(isLocked);
    map['received_at'] = Variable<DateTime>(receivedAt);
    return map;
  }

  MessagesTableCompanion toCompanion(bool nullToAbsent) {
    return MessagesTableCompanion(
      id: Value(id),
      accountId: Value(accountId),
      remoteMessageId: Value(remoteMessageId),
      threadId: threadId == null && nullToAbsent
          ? const Value.absent()
          : Value(threadId),
      senderEmail: Value(senderEmail),
      senderName: Value(senderName),
      subject: Value(subject),
      snippet: Value(snippet),
      plainTextBody: Value(plainTextBody),
      category: Value(category),
      customTag: customTag == null && nullToAbsent
          ? const Value.absent()
          : Value(customTag),
      unsubscribeUrl: unsubscribeUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(unsubscribeUrl),
      unsubscribeMailto: unsubscribeMailto == null && nullToAbsent
          ? const Value.absent()
          : Value(unsubscribeMailto),
      isRead: Value(isRead),
      isArchived: Value(isArchived),
      isStarred: Value(isStarred),
      isLocked: Value(isLocked),
      receivedAt: Value(receivedAt),
    );
  }

  factory MessageEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageEntry(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      remoteMessageId: serializer.fromJson<String>(json['remoteMessageId']),
      threadId: serializer.fromJson<String?>(json['threadId']),
      senderEmail: serializer.fromJson<String>(json['senderEmail']),
      senderName: serializer.fromJson<String>(json['senderName']),
      subject: serializer.fromJson<String>(json['subject']),
      snippet: serializer.fromJson<String>(json['snippet']),
      plainTextBody: serializer.fromJson<String>(json['plainTextBody']),
      category: serializer.fromJson<String>(json['category']),
      customTag: serializer.fromJson<String?>(json['customTag']),
      unsubscribeUrl: serializer.fromJson<String?>(json['unsubscribeUrl']),
      unsubscribeMailto:
          serializer.fromJson<String?>(json['unsubscribeMailto']),
      isRead: serializer.fromJson<bool>(json['isRead']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      isStarred: serializer.fromJson<bool>(json['isStarred']),
      isLocked: serializer.fromJson<bool>(json['isLocked']),
      receivedAt: serializer.fromJson<DateTime>(json['receivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'remoteMessageId': serializer.toJson<String>(remoteMessageId),
      'threadId': serializer.toJson<String?>(threadId),
      'senderEmail': serializer.toJson<String>(senderEmail),
      'senderName': serializer.toJson<String>(senderName),
      'subject': serializer.toJson<String>(subject),
      'snippet': serializer.toJson<String>(snippet),
      'plainTextBody': serializer.toJson<String>(plainTextBody),
      'category': serializer.toJson<String>(category),
      'customTag': serializer.toJson<String?>(customTag),
      'unsubscribeUrl': serializer.toJson<String?>(unsubscribeUrl),
      'unsubscribeMailto': serializer.toJson<String?>(unsubscribeMailto),
      'isRead': serializer.toJson<bool>(isRead),
      'isArchived': serializer.toJson<bool>(isArchived),
      'isStarred': serializer.toJson<bool>(isStarred),
      'isLocked': serializer.toJson<bool>(isLocked),
      'receivedAt': serializer.toJson<DateTime>(receivedAt),
    };
  }

  MessageEntry copyWith(
          {String? id,
          String? accountId,
          String? remoteMessageId,
          Value<String?> threadId = const Value.absent(),
          String? senderEmail,
          String? senderName,
          String? subject,
          String? snippet,
          String? plainTextBody,
          String? category,
          Value<String?> customTag = const Value.absent(),
          Value<String?> unsubscribeUrl = const Value.absent(),
          Value<String?> unsubscribeMailto = const Value.absent(),
          bool? isRead,
          bool? isArchived,
          bool? isStarred,
          bool? isLocked,
          DateTime? receivedAt}) =>
      MessageEntry(
        id: id ?? this.id,
        accountId: accountId ?? this.accountId,
        remoteMessageId: remoteMessageId ?? this.remoteMessageId,
        threadId: threadId.present ? threadId.value : this.threadId,
        senderEmail: senderEmail ?? this.senderEmail,
        senderName: senderName ?? this.senderName,
        subject: subject ?? this.subject,
        snippet: snippet ?? this.snippet,
        plainTextBody: plainTextBody ?? this.plainTextBody,
        category: category ?? this.category,
        customTag: customTag.present ? customTag.value : this.customTag,
        unsubscribeUrl:
            unsubscribeUrl.present ? unsubscribeUrl.value : this.unsubscribeUrl,
        unsubscribeMailto: unsubscribeMailto.present
            ? unsubscribeMailto.value
            : this.unsubscribeMailto,
        isRead: isRead ?? this.isRead,
        isArchived: isArchived ?? this.isArchived,
        isStarred: isStarred ?? this.isStarred,
        isLocked: isLocked ?? this.isLocked,
        receivedAt: receivedAt ?? this.receivedAt,
      );
  MessageEntry copyWithCompanion(MessagesTableCompanion data) {
    return MessageEntry(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      remoteMessageId: data.remoteMessageId.present
          ? data.remoteMessageId.value
          : this.remoteMessageId,
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
      senderEmail:
          data.senderEmail.present ? data.senderEmail.value : this.senderEmail,
      senderName:
          data.senderName.present ? data.senderName.value : this.senderName,
      subject: data.subject.present ? data.subject.value : this.subject,
      snippet: data.snippet.present ? data.snippet.value : this.snippet,
      plainTextBody: data.plainTextBody.present
          ? data.plainTextBody.value
          : this.plainTextBody,
      category: data.category.present ? data.category.value : this.category,
      customTag: data.customTag.present ? data.customTag.value : this.customTag,
      unsubscribeUrl: data.unsubscribeUrl.present
          ? data.unsubscribeUrl.value
          : this.unsubscribeUrl,
      unsubscribeMailto: data.unsubscribeMailto.present
          ? data.unsubscribeMailto.value
          : this.unsubscribeMailto,
      isRead: data.isRead.present ? data.isRead.value : this.isRead,
      isArchived:
          data.isArchived.present ? data.isArchived.value : this.isArchived,
      isStarred: data.isStarred.present ? data.isStarred.value : this.isStarred,
      isLocked: data.isLocked.present ? data.isLocked.value : this.isLocked,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageEntry(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('remoteMessageId: $remoteMessageId, ')
          ..write('threadId: $threadId, ')
          ..write('senderEmail: $senderEmail, ')
          ..write('senderName: $senderName, ')
          ..write('subject: $subject, ')
          ..write('snippet: $snippet, ')
          ..write('plainTextBody: $plainTextBody, ')
          ..write('category: $category, ')
          ..write('customTag: $customTag, ')
          ..write('unsubscribeUrl: $unsubscribeUrl, ')
          ..write('unsubscribeMailto: $unsubscribeMailto, ')
          ..write('isRead: $isRead, ')
          ..write('isArchived: $isArchived, ')
          ..write('isStarred: $isStarred, ')
          ..write('isLocked: $isLocked, ')
          ..write('receivedAt: $receivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      accountId,
      remoteMessageId,
      threadId,
      senderEmail,
      senderName,
      subject,
      snippet,
      plainTextBody,
      category,
      customTag,
      unsubscribeUrl,
      unsubscribeMailto,
      isRead,
      isArchived,
      isStarred,
      isLocked,
      receivedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageEntry &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.remoteMessageId == this.remoteMessageId &&
          other.threadId == this.threadId &&
          other.senderEmail == this.senderEmail &&
          other.senderName == this.senderName &&
          other.subject == this.subject &&
          other.snippet == this.snippet &&
          other.plainTextBody == this.plainTextBody &&
          other.category == this.category &&
          other.customTag == this.customTag &&
          other.unsubscribeUrl == this.unsubscribeUrl &&
          other.unsubscribeMailto == this.unsubscribeMailto &&
          other.isRead == this.isRead &&
          other.isArchived == this.isArchived &&
          other.isStarred == this.isStarred &&
          other.isLocked == this.isLocked &&
          other.receivedAt == this.receivedAt);
}

class MessagesTableCompanion extends UpdateCompanion<MessageEntry> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> remoteMessageId;
  final Value<String?> threadId;
  final Value<String> senderEmail;
  final Value<String> senderName;
  final Value<String> subject;
  final Value<String> snippet;
  final Value<String> plainTextBody;
  final Value<String> category;
  final Value<String?> customTag;
  final Value<String?> unsubscribeUrl;
  final Value<String?> unsubscribeMailto;
  final Value<bool> isRead;
  final Value<bool> isArchived;
  final Value<bool> isStarred;
  final Value<bool> isLocked;
  final Value<DateTime> receivedAt;
  final Value<int> rowid;
  const MessagesTableCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.remoteMessageId = const Value.absent(),
    this.threadId = const Value.absent(),
    this.senderEmail = const Value.absent(),
    this.senderName = const Value.absent(),
    this.subject = const Value.absent(),
    this.snippet = const Value.absent(),
    this.plainTextBody = const Value.absent(),
    this.category = const Value.absent(),
    this.customTag = const Value.absent(),
    this.unsubscribeUrl = const Value.absent(),
    this.unsubscribeMailto = const Value.absent(),
    this.isRead = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isStarred = const Value.absent(),
    this.isLocked = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesTableCompanion.insert({
    required String id,
    required String accountId,
    required String remoteMessageId,
    this.threadId = const Value.absent(),
    required String senderEmail,
    required String senderName,
    required String subject,
    required String snippet,
    required String plainTextBody,
    required String category,
    this.customTag = const Value.absent(),
    this.unsubscribeUrl = const Value.absent(),
    this.unsubscribeMailto = const Value.absent(),
    this.isRead = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isStarred = const Value.absent(),
    this.isLocked = const Value.absent(),
    required DateTime receivedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        accountId = Value(accountId),
        remoteMessageId = Value(remoteMessageId),
        senderEmail = Value(senderEmail),
        senderName = Value(senderName),
        subject = Value(subject),
        snippet = Value(snippet),
        plainTextBody = Value(plainTextBody),
        category = Value(category),
        receivedAt = Value(receivedAt);
  static Insertable<MessageEntry> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? remoteMessageId,
    Expression<String>? threadId,
    Expression<String>? senderEmail,
    Expression<String>? senderName,
    Expression<String>? subject,
    Expression<String>? snippet,
    Expression<String>? plainTextBody,
    Expression<String>? category,
    Expression<String>? customTag,
    Expression<String>? unsubscribeUrl,
    Expression<String>? unsubscribeMailto,
    Expression<bool>? isRead,
    Expression<bool>? isArchived,
    Expression<bool>? isStarred,
    Expression<bool>? isLocked,
    Expression<DateTime>? receivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (remoteMessageId != null) 'remote_message_id': remoteMessageId,
      if (threadId != null) 'thread_id': threadId,
      if (senderEmail != null) 'sender_email': senderEmail,
      if (senderName != null) 'sender_name': senderName,
      if (subject != null) 'subject': subject,
      if (snippet != null) 'snippet': snippet,
      if (plainTextBody != null) 'plain_text_body': plainTextBody,
      if (category != null) 'category': category,
      if (customTag != null) 'custom_tag': customTag,
      if (unsubscribeUrl != null) 'unsubscribe_url': unsubscribeUrl,
      if (unsubscribeMailto != null) 'unsubscribe_mailto': unsubscribeMailto,
      if (isRead != null) 'is_read': isRead,
      if (isArchived != null) 'is_archived': isArchived,
      if (isStarred != null) 'is_starred': isStarred,
      if (isLocked != null) 'is_locked': isLocked,
      if (receivedAt != null) 'received_at': receivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? accountId,
      Value<String>? remoteMessageId,
      Value<String?>? threadId,
      Value<String>? senderEmail,
      Value<String>? senderName,
      Value<String>? subject,
      Value<String>? snippet,
      Value<String>? plainTextBody,
      Value<String>? category,
      Value<String?>? customTag,
      Value<String?>? unsubscribeUrl,
      Value<String?>? unsubscribeMailto,
      Value<bool>? isRead,
      Value<bool>? isArchived,
      Value<bool>? isStarred,
      Value<bool>? isLocked,
      Value<DateTime>? receivedAt,
      Value<int>? rowid}) {
    return MessagesTableCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      remoteMessageId: remoteMessageId ?? this.remoteMessageId,
      threadId: threadId ?? this.threadId,
      senderEmail: senderEmail ?? this.senderEmail,
      senderName: senderName ?? this.senderName,
      subject: subject ?? this.subject,
      snippet: snippet ?? this.snippet,
      plainTextBody: plainTextBody ?? this.plainTextBody,
      category: category ?? this.category,
      customTag: customTag ?? this.customTag,
      unsubscribeUrl: unsubscribeUrl ?? this.unsubscribeUrl,
      unsubscribeMailto: unsubscribeMailto ?? this.unsubscribeMailto,
      isRead: isRead ?? this.isRead,
      isArchived: isArchived ?? this.isArchived,
      isStarred: isStarred ?? this.isStarred,
      isLocked: isLocked ?? this.isLocked,
      receivedAt: receivedAt ?? this.receivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (remoteMessageId.present) {
      map['remote_message_id'] = Variable<String>(remoteMessageId.value);
    }
    if (threadId.present) {
      map['thread_id'] = Variable<String>(threadId.value);
    }
    if (senderEmail.present) {
      map['sender_email'] = Variable<String>(senderEmail.value);
    }
    if (senderName.present) {
      map['sender_name'] = Variable<String>(senderName.value);
    }
    if (subject.present) {
      map['subject'] = Variable<String>(subject.value);
    }
    if (snippet.present) {
      map['snippet'] = Variable<String>(snippet.value);
    }
    if (plainTextBody.present) {
      map['plain_text_body'] = Variable<String>(plainTextBody.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (customTag.present) {
      map['custom_tag'] = Variable<String>(customTag.value);
    }
    if (unsubscribeUrl.present) {
      map['unsubscribe_url'] = Variable<String>(unsubscribeUrl.value);
    }
    if (unsubscribeMailto.present) {
      map['unsubscribe_mailto'] = Variable<String>(unsubscribeMailto.value);
    }
    if (isRead.present) {
      map['is_read'] = Variable<bool>(isRead.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (isStarred.present) {
      map['is_starred'] = Variable<bool>(isStarred.value);
    }
    if (isLocked.present) {
      map['is_locked'] = Variable<bool>(isLocked.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<DateTime>(receivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesTableCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('remoteMessageId: $remoteMessageId, ')
          ..write('threadId: $threadId, ')
          ..write('senderEmail: $senderEmail, ')
          ..write('senderName: $senderName, ')
          ..write('subject: $subject, ')
          ..write('snippet: $snippet, ')
          ..write('plainTextBody: $plainTextBody, ')
          ..write('category: $category, ')
          ..write('customTag: $customTag, ')
          ..write('unsubscribeUrl: $unsubscribeUrl, ')
          ..write('unsubscribeMailto: $unsubscribeMailto, ')
          ..write('isRead: $isRead, ')
          ..write('isArchived: $isArchived, ')
          ..write('isStarred: $isStarred, ')
          ..write('isLocked: $isLocked, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SenderRulesTableTable extends SenderRulesTable
    with TableInfo<$SenderRulesTableTable, SenderRuleEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SenderRulesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _senderEmailMeta =
      const VerificationMeta('senderEmail');
  @override
  late final GeneratedColumn<String> senderEmail = GeneratedColumn<String>(
      'sender_email', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _preferredCategoryMeta =
      const VerificationMeta('preferredCategory');
  @override
  late final GeneratedColumn<String> preferredCategory =
      GeneratedColumn<String>('preferred_category', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _customTagMeta =
      const VerificationMeta('customTag');
  @override
  late final GeneratedColumn<String> customTag = GeneratedColumn<String>(
      'custom_tag', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isAutoLockedMeta =
      const VerificationMeta('isAutoLocked');
  @override
  late final GeneratedColumn<bool> isAutoLocked = GeneratedColumn<bool>(
      'is_auto_locked', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_auto_locked" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        senderEmail,
        preferredCategory,
        customTag,
        isAutoLocked,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sender_rules_table';
  @override
  VerificationContext validateIntegrity(Insertable<SenderRuleEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sender_email')) {
      context.handle(
          _senderEmailMeta,
          senderEmail.isAcceptableOrUnknown(
              data['sender_email']!, _senderEmailMeta));
    } else if (isInserting) {
      context.missing(_senderEmailMeta);
    }
    if (data.containsKey('preferred_category')) {
      context.handle(
          _preferredCategoryMeta,
          preferredCategory.isAcceptableOrUnknown(
              data['preferred_category']!, _preferredCategoryMeta));
    } else if (isInserting) {
      context.missing(_preferredCategoryMeta);
    }
    if (data.containsKey('custom_tag')) {
      context.handle(_customTagMeta,
          customTag.isAcceptableOrUnknown(data['custom_tag']!, _customTagMeta));
    }
    if (data.containsKey('is_auto_locked')) {
      context.handle(
          _isAutoLockedMeta,
          isAutoLocked.isAcceptableOrUnknown(
              data['is_auto_locked']!, _isAutoLockedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {senderEmail};
  @override
  SenderRuleEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SenderRuleEntry(
      senderEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_email'])!,
      preferredCategory: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}preferred_category'])!,
      customTag: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}custom_tag']),
      isAutoLocked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_auto_locked'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SenderRulesTableTable createAlias(String alias) {
    return $SenderRulesTableTable(attachedDatabase, alias);
  }
}

class SenderRuleEntry extends DataClass implements Insertable<SenderRuleEntry> {
  final String senderEmail;
  final String preferredCategory;
  final String? customTag;
  final bool isAutoLocked;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SenderRuleEntry(
      {required this.senderEmail,
      required this.preferredCategory,
      this.customTag,
      required this.isAutoLocked,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sender_email'] = Variable<String>(senderEmail);
    map['preferred_category'] = Variable<String>(preferredCategory);
    if (!nullToAbsent || customTag != null) {
      map['custom_tag'] = Variable<String>(customTag);
    }
    map['is_auto_locked'] = Variable<bool>(isAutoLocked);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SenderRulesTableCompanion toCompanion(bool nullToAbsent) {
    return SenderRulesTableCompanion(
      senderEmail: Value(senderEmail),
      preferredCategory: Value(preferredCategory),
      customTag: customTag == null && nullToAbsent
          ? const Value.absent()
          : Value(customTag),
      isAutoLocked: Value(isAutoLocked),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SenderRuleEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SenderRuleEntry(
      senderEmail: serializer.fromJson<String>(json['senderEmail']),
      preferredCategory: serializer.fromJson<String>(json['preferredCategory']),
      customTag: serializer.fromJson<String?>(json['customTag']),
      isAutoLocked: serializer.fromJson<bool>(json['isAutoLocked']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'senderEmail': serializer.toJson<String>(senderEmail),
      'preferredCategory': serializer.toJson<String>(preferredCategory),
      'customTag': serializer.toJson<String?>(customTag),
      'isAutoLocked': serializer.toJson<bool>(isAutoLocked),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SenderRuleEntry copyWith(
          {String? senderEmail,
          String? preferredCategory,
          Value<String?> customTag = const Value.absent(),
          bool? isAutoLocked,
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      SenderRuleEntry(
        senderEmail: senderEmail ?? this.senderEmail,
        preferredCategory: preferredCategory ?? this.preferredCategory,
        customTag: customTag.present ? customTag.value : this.customTag,
        isAutoLocked: isAutoLocked ?? this.isAutoLocked,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SenderRuleEntry copyWithCompanion(SenderRulesTableCompanion data) {
    return SenderRuleEntry(
      senderEmail:
          data.senderEmail.present ? data.senderEmail.value : this.senderEmail,
      preferredCategory: data.preferredCategory.present
          ? data.preferredCategory.value
          : this.preferredCategory,
      customTag: data.customTag.present ? data.customTag.value : this.customTag,
      isAutoLocked: data.isAutoLocked.present
          ? data.isAutoLocked.value
          : this.isAutoLocked,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SenderRuleEntry(')
          ..write('senderEmail: $senderEmail, ')
          ..write('preferredCategory: $preferredCategory, ')
          ..write('customTag: $customTag, ')
          ..write('isAutoLocked: $isAutoLocked, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(senderEmail, preferredCategory, customTag,
      isAutoLocked, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SenderRuleEntry &&
          other.senderEmail == this.senderEmail &&
          other.preferredCategory == this.preferredCategory &&
          other.customTag == this.customTag &&
          other.isAutoLocked == this.isAutoLocked &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SenderRulesTableCompanion extends UpdateCompanion<SenderRuleEntry> {
  final Value<String> senderEmail;
  final Value<String> preferredCategory;
  final Value<String?> customTag;
  final Value<bool> isAutoLocked;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SenderRulesTableCompanion({
    this.senderEmail = const Value.absent(),
    this.preferredCategory = const Value.absent(),
    this.customTag = const Value.absent(),
    this.isAutoLocked = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SenderRulesTableCompanion.insert({
    required String senderEmail,
    required String preferredCategory,
    this.customTag = const Value.absent(),
    this.isAutoLocked = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : senderEmail = Value(senderEmail),
        preferredCategory = Value(preferredCategory),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<SenderRuleEntry> custom({
    Expression<String>? senderEmail,
    Expression<String>? preferredCategory,
    Expression<String>? customTag,
    Expression<bool>? isAutoLocked,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (senderEmail != null) 'sender_email': senderEmail,
      if (preferredCategory != null) 'preferred_category': preferredCategory,
      if (customTag != null) 'custom_tag': customTag,
      if (isAutoLocked != null) 'is_auto_locked': isAutoLocked,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SenderRulesTableCompanion copyWith(
      {Value<String>? senderEmail,
      Value<String>? preferredCategory,
      Value<String?>? customTag,
      Value<bool>? isAutoLocked,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return SenderRulesTableCompanion(
      senderEmail: senderEmail ?? this.senderEmail,
      preferredCategory: preferredCategory ?? this.preferredCategory,
      customTag: customTag ?? this.customTag,
      isAutoLocked: isAutoLocked ?? this.isAutoLocked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (senderEmail.present) {
      map['sender_email'] = Variable<String>(senderEmail.value);
    }
    if (preferredCategory.present) {
      map['preferred_category'] = Variable<String>(preferredCategory.value);
    }
    if (customTag.present) {
      map['custom_tag'] = Variable<String>(customTag.value);
    }
    if (isAutoLocked.present) {
      map['is_auto_locked'] = Variable<bool>(isAutoLocked.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
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
    return (StringBuffer('SenderRulesTableCompanion(')
          ..write('senderEmail: $senderEmail, ')
          ..write('preferredCategory: $preferredCategory, ')
          ..write('customTag: $customTag, ')
          ..write('isAutoLocked: $isAutoLocked, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTableTable accountsTable = $AccountsTableTable(this);
  late final $MessagesTableTable messagesTable = $MessagesTableTable(this);
  late final $SenderRulesTableTable senderRulesTable =
      $SenderRulesTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [accountsTable, messagesTable, senderRulesTable];
}

typedef $$AccountsTableTableCreateCompanionBuilder = AccountsTableCompanion
    Function({
  required String id,
  required String email,
  required String displayName,
  required String provider,
  required int avatarColorValue,
  Value<DateTime?> lastSyncedAt,
  Value<int> totalMessages,
  Value<int> rowid,
});
typedef $$AccountsTableTableUpdateCompanionBuilder = AccountsTableCompanion
    Function({
  Value<String> id,
  Value<String> email,
  Value<String> displayName,
  Value<String> provider,
  Value<int> avatarColorValue,
  Value<DateTime?> lastSyncedAt,
  Value<int> totalMessages,
  Value<int> rowid,
});

class $$AccountsTableTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTableTable> {
  $$AccountsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get avatarColorValue => $composableBuilder(
      column: $table.avatarColorValue,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalMessages => $composableBuilder(
      column: $table.totalMessages, builder: (column) => ColumnFilters(column));
}

class $$AccountsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTableTable> {
  $$AccountsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email => $composableBuilder(
      column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get provider => $composableBuilder(
      column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get avatarColorValue => $composableBuilder(
      column: $table.avatarColorValue,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalMessages => $composableBuilder(
      column: $table.totalMessages,
      builder: (column) => ColumnOrderings(column));
}

class $$AccountsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTableTable> {
  $$AccountsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<int> get avatarColorValue => $composableBuilder(
      column: $table.avatarColorValue, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => column);

  GeneratedColumn<int> get totalMessages => $composableBuilder(
      column: $table.totalMessages, builder: (column) => column);
}

class $$AccountsTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AccountsTableTable,
    AccountEntry,
    $$AccountsTableTableFilterComposer,
    $$AccountsTableTableOrderingComposer,
    $$AccountsTableTableAnnotationComposer,
    $$AccountsTableTableCreateCompanionBuilder,
    $$AccountsTableTableUpdateCompanionBuilder,
    (
      AccountEntry,
      BaseReferences<_$AppDatabase, $AccountsTableTable, AccountEntry>
    ),
    AccountEntry,
    PrefetchHooks Function()> {
  $$AccountsTableTableTableManager(_$AppDatabase db, $AccountsTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> email = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String> provider = const Value.absent(),
            Value<int> avatarColorValue = const Value.absent(),
            Value<DateTime?> lastSyncedAt = const Value.absent(),
            Value<int> totalMessages = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AccountsTableCompanion(
            id: id,
            email: email,
            displayName: displayName,
            provider: provider,
            avatarColorValue: avatarColorValue,
            lastSyncedAt: lastSyncedAt,
            totalMessages: totalMessages,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String email,
            required String displayName,
            required String provider,
            required int avatarColorValue,
            Value<DateTime?> lastSyncedAt = const Value.absent(),
            Value<int> totalMessages = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AccountsTableCompanion.insert(
            id: id,
            email: email,
            displayName: displayName,
            provider: provider,
            avatarColorValue: avatarColorValue,
            lastSyncedAt: lastSyncedAt,
            totalMessages: totalMessages,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AccountsTableTable, AccountEntry>(table),
                    BaseReferences<_$AppDatabase, $AccountsTableTable,
                        AccountEntry>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AccountsTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AccountsTableTable,
    AccountEntry,
    $$AccountsTableTableFilterComposer,
    $$AccountsTableTableOrderingComposer,
    $$AccountsTableTableAnnotationComposer,
    $$AccountsTableTableCreateCompanionBuilder,
    $$AccountsTableTableUpdateCompanionBuilder,
    (
      AccountEntry,
      BaseReferences<_$AppDatabase, $AccountsTableTable, AccountEntry>
    ),
    AccountEntry,
    PrefetchHooks Function()>;
typedef $$MessagesTableTableCreateCompanionBuilder = MessagesTableCompanion
    Function({
  required String id,
  required String accountId,
  required String remoteMessageId,
  Value<String?> threadId,
  required String senderEmail,
  required String senderName,
  required String subject,
  required String snippet,
  required String plainTextBody,
  required String category,
  Value<String?> customTag,
  Value<String?> unsubscribeUrl,
  Value<String?> unsubscribeMailto,
  Value<bool> isRead,
  Value<bool> isArchived,
  Value<bool> isStarred,
  Value<bool> isLocked,
  required DateTime receivedAt,
  Value<int> rowid,
});
typedef $$MessagesTableTableUpdateCompanionBuilder = MessagesTableCompanion
    Function({
  Value<String> id,
  Value<String> accountId,
  Value<String> remoteMessageId,
  Value<String?> threadId,
  Value<String> senderEmail,
  Value<String> senderName,
  Value<String> subject,
  Value<String> snippet,
  Value<String> plainTextBody,
  Value<String> category,
  Value<String?> customTag,
  Value<String?> unsubscribeUrl,
  Value<String?> unsubscribeMailto,
  Value<bool> isRead,
  Value<bool> isArchived,
  Value<bool> isStarred,
  Value<bool> isLocked,
  Value<DateTime> receivedAt,
  Value<int> rowid,
});

class $$MessagesTableTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteMessageId => $composableBuilder(
      column: $table.remoteMessageId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get threadId => $composableBuilder(
      column: $table.threadId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderEmail => $composableBuilder(
      column: $table.senderEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get snippet => $composableBuilder(
      column: $table.snippet, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get plainTextBody => $composableBuilder(
      column: $table.plainTextBody, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customTag => $composableBuilder(
      column: $table.customTag, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unsubscribeUrl => $composableBuilder(
      column: $table.unsubscribeUrl,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unsubscribeMailto => $composableBuilder(
      column: $table.unsubscribeMailto,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isStarred => $composableBuilder(
      column: $table.isStarred, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isLocked => $composableBuilder(
      column: $table.isLocked, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnFilters(column));
}

class $$MessagesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteMessageId => $composableBuilder(
      column: $table.remoteMessageId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get threadId => $composableBuilder(
      column: $table.threadId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderEmail => $composableBuilder(
      column: $table.senderEmail, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subject => $composableBuilder(
      column: $table.subject, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get snippet => $composableBuilder(
      column: $table.snippet, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plainTextBody => $composableBuilder(
      column: $table.plainTextBody,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customTag => $composableBuilder(
      column: $table.customTag, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unsubscribeUrl => $composableBuilder(
      column: $table.unsubscribeUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unsubscribeMailto => $composableBuilder(
      column: $table.unsubscribeMailto,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRead => $composableBuilder(
      column: $table.isRead, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isStarred => $composableBuilder(
      column: $table.isStarred, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isLocked => $composableBuilder(
      column: $table.isLocked, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnOrderings(column));
}

class $$MessagesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTableTable> {
  $$MessagesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get remoteMessageId => $composableBuilder(
      column: $table.remoteMessageId, builder: (column) => column);

  GeneratedColumn<String> get threadId =>
      $composableBuilder(column: $table.threadId, builder: (column) => column);

  GeneratedColumn<String> get senderEmail => $composableBuilder(
      column: $table.senderEmail, builder: (column) => column);

  GeneratedColumn<String> get senderName => $composableBuilder(
      column: $table.senderName, builder: (column) => column);

  GeneratedColumn<String> get subject =>
      $composableBuilder(column: $table.subject, builder: (column) => column);

  GeneratedColumn<String> get snippet =>
      $composableBuilder(column: $table.snippet, builder: (column) => column);

  GeneratedColumn<String> get plainTextBody => $composableBuilder(
      column: $table.plainTextBody, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get customTag =>
      $composableBuilder(column: $table.customTag, builder: (column) => column);

  GeneratedColumn<String> get unsubscribeUrl => $composableBuilder(
      column: $table.unsubscribeUrl, builder: (column) => column);

  GeneratedColumn<String> get unsubscribeMailto => $composableBuilder(
      column: $table.unsubscribeMailto, builder: (column) => column);

  GeneratedColumn<bool> get isRead =>
      $composableBuilder(column: $table.isRead, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
      column: $table.isArchived, builder: (column) => column);

  GeneratedColumn<bool> get isStarred =>
      $composableBuilder(column: $table.isStarred, builder: (column) => column);

  GeneratedColumn<bool> get isLocked =>
      $composableBuilder(column: $table.isLocked, builder: (column) => column);

  GeneratedColumn<DateTime> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => column);
}

class $$MessagesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MessagesTableTable,
    MessageEntry,
    $$MessagesTableTableFilterComposer,
    $$MessagesTableTableOrderingComposer,
    $$MessagesTableTableAnnotationComposer,
    $$MessagesTableTableCreateCompanionBuilder,
    $$MessagesTableTableUpdateCompanionBuilder,
    (
      MessageEntry,
      BaseReferences<_$AppDatabase, $MessagesTableTable, MessageEntry>
    ),
    MessageEntry,
    PrefetchHooks Function()> {
  $$MessagesTableTableTableManager(_$AppDatabase db, $MessagesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> accountId = const Value.absent(),
            Value<String> remoteMessageId = const Value.absent(),
            Value<String?> threadId = const Value.absent(),
            Value<String> senderEmail = const Value.absent(),
            Value<String> senderName = const Value.absent(),
            Value<String> subject = const Value.absent(),
            Value<String> snippet = const Value.absent(),
            Value<String> plainTextBody = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String?> customTag = const Value.absent(),
            Value<String?> unsubscribeUrl = const Value.absent(),
            Value<String?> unsubscribeMailto = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<bool> isStarred = const Value.absent(),
            Value<bool> isLocked = const Value.absent(),
            Value<DateTime> receivedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesTableCompanion(
            id: id,
            accountId: accountId,
            remoteMessageId: remoteMessageId,
            threadId: threadId,
            senderEmail: senderEmail,
            senderName: senderName,
            subject: subject,
            snippet: snippet,
            plainTextBody: plainTextBody,
            category: category,
            customTag: customTag,
            unsubscribeUrl: unsubscribeUrl,
            unsubscribeMailto: unsubscribeMailto,
            isRead: isRead,
            isArchived: isArchived,
            isStarred: isStarred,
            isLocked: isLocked,
            receivedAt: receivedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String accountId,
            required String remoteMessageId,
            Value<String?> threadId = const Value.absent(),
            required String senderEmail,
            required String senderName,
            required String subject,
            required String snippet,
            required String plainTextBody,
            required String category,
            Value<String?> customTag = const Value.absent(),
            Value<String?> unsubscribeUrl = const Value.absent(),
            Value<String?> unsubscribeMailto = const Value.absent(),
            Value<bool> isRead = const Value.absent(),
            Value<bool> isArchived = const Value.absent(),
            Value<bool> isStarred = const Value.absent(),
            Value<bool> isLocked = const Value.absent(),
            required DateTime receivedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              MessagesTableCompanion.insert(
            id: id,
            accountId: accountId,
            remoteMessageId: remoteMessageId,
            threadId: threadId,
            senderEmail: senderEmail,
            senderName: senderName,
            subject: subject,
            snippet: snippet,
            plainTextBody: plainTextBody,
            category: category,
            customTag: customTag,
            unsubscribeUrl: unsubscribeUrl,
            unsubscribeMailto: unsubscribeMailto,
            isRead: isRead,
            isArchived: isArchived,
            isStarred: isStarred,
            isLocked: isLocked,
            receivedAt: receivedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MessagesTableTable, MessageEntry>(table),
                    BaseReferences<_$AppDatabase, $MessagesTableTable,
                        MessageEntry>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MessagesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MessagesTableTable,
    MessageEntry,
    $$MessagesTableTableFilterComposer,
    $$MessagesTableTableOrderingComposer,
    $$MessagesTableTableAnnotationComposer,
    $$MessagesTableTableCreateCompanionBuilder,
    $$MessagesTableTableUpdateCompanionBuilder,
    (
      MessageEntry,
      BaseReferences<_$AppDatabase, $MessagesTableTable, MessageEntry>
    ),
    MessageEntry,
    PrefetchHooks Function()>;
typedef $$SenderRulesTableTableCreateCompanionBuilder
    = SenderRulesTableCompanion Function({
  required String senderEmail,
  required String preferredCategory,
  Value<String?> customTag,
  Value<bool> isAutoLocked,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$SenderRulesTableTableUpdateCompanionBuilder
    = SenderRulesTableCompanion Function({
  Value<String> senderEmail,
  Value<String> preferredCategory,
  Value<String?> customTag,
  Value<bool> isAutoLocked,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SenderRulesTableTableFilterComposer
    extends Composer<_$AppDatabase, $SenderRulesTableTable> {
  $$SenderRulesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get senderEmail => $composableBuilder(
      column: $table.senderEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preferredCategory => $composableBuilder(
      column: $table.preferredCategory,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get customTag => $composableBuilder(
      column: $table.customTag, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isAutoLocked => $composableBuilder(
      column: $table.isAutoLocked, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SenderRulesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SenderRulesTableTable> {
  $$SenderRulesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get senderEmail => $composableBuilder(
      column: $table.senderEmail, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preferredCategory => $composableBuilder(
      column: $table.preferredCategory,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get customTag => $composableBuilder(
      column: $table.customTag, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isAutoLocked => $composableBuilder(
      column: $table.isAutoLocked,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SenderRulesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SenderRulesTableTable> {
  $$SenderRulesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get senderEmail => $composableBuilder(
      column: $table.senderEmail, builder: (column) => column);

  GeneratedColumn<String> get preferredCategory => $composableBuilder(
      column: $table.preferredCategory, builder: (column) => column);

  GeneratedColumn<String> get customTag =>
      $composableBuilder(column: $table.customTag, builder: (column) => column);

  GeneratedColumn<bool> get isAutoLocked => $composableBuilder(
      column: $table.isAutoLocked, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SenderRulesTableTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SenderRulesTableTable,
    SenderRuleEntry,
    $$SenderRulesTableTableFilterComposer,
    $$SenderRulesTableTableOrderingComposer,
    $$SenderRulesTableTableAnnotationComposer,
    $$SenderRulesTableTableCreateCompanionBuilder,
    $$SenderRulesTableTableUpdateCompanionBuilder,
    (
      SenderRuleEntry,
      BaseReferences<_$AppDatabase, $SenderRulesTableTable, SenderRuleEntry>
    ),
    SenderRuleEntry,
    PrefetchHooks Function()> {
  $$SenderRulesTableTableTableManager(
      _$AppDatabase db, $SenderRulesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SenderRulesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SenderRulesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SenderRulesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> senderEmail = const Value.absent(),
            Value<String> preferredCategory = const Value.absent(),
            Value<String?> customTag = const Value.absent(),
            Value<bool> isAutoLocked = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SenderRulesTableCompanion(
            senderEmail: senderEmail,
            preferredCategory: preferredCategory,
            customTag: customTag,
            isAutoLocked: isAutoLocked,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String senderEmail,
            required String preferredCategory,
            Value<String?> customTag = const Value.absent(),
            Value<bool> isAutoLocked = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SenderRulesTableCompanion.insert(
            senderEmail: senderEmail,
            preferredCategory: preferredCategory,
            customTag: customTag,
            isAutoLocked: isAutoLocked,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SenderRulesTableTable, SenderRuleEntry>(table),
                    BaseReferences<_$AppDatabase, $SenderRulesTableTable,
                        SenderRuleEntry>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SenderRulesTableTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SenderRulesTableTable,
    SenderRuleEntry,
    $$SenderRulesTableTableFilterComposer,
    $$SenderRulesTableTableOrderingComposer,
    $$SenderRulesTableTableAnnotationComposer,
    $$SenderRulesTableTableCreateCompanionBuilder,
    $$SenderRulesTableTableUpdateCompanionBuilder,
    (
      SenderRuleEntry,
      BaseReferences<_$AppDatabase, $SenderRulesTableTable, SenderRuleEntry>
    ),
    SenderRuleEntry,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableTableManager get accountsTable =>
      $$AccountsTableTableTableManager(_db, _db.accountsTable);
  $$MessagesTableTableTableManager get messagesTable =>
      $$MessagesTableTableTableManager(_db, _db.messagesTable);
  $$SenderRulesTableTableTableManager get senderRulesTable =>
      $$SenderRulesTableTableTableManager(_db, _db.senderRulesTable);
}
