import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

const _copyWithUnset = Object();

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

String normalizeGroupJoinPin(String? value, {String? fallbackSeed}) {
  final digitsOnly = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.length == 4) {
    return digitsOnly;
  }
  return _legacyGroupJoinPin(fallbackSeed ?? 'shardpay');
}

String generateGroupJoinPin() {
  final pin = math.Random.secure().nextInt(10000);
  return pin.toString().padLeft(4, '0');
}

String _legacyGroupJoinPin(String seed) {
  var hash = 0;
  for (final codeUnit in seed.codeUnits) {
    hash = ((hash * 31) + codeUnit) % 10000;
  }
  return hash.toString().padLeft(4, '0');
}

class AppUser {
  const AppUser({required this.id, required this.email, required this.displayName, required this.createdAt, this.photoUrl});

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final String? photoUrl;

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'createdAt': createdAt.toIso8601String(),
    'photoUrl': photoUrl,
  };

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? 'Sin nombre',
      createdAt: _toDateTime(map['createdAt']),
      photoUrl: map['photoUrl'] as String?,
    );
  }
}

class GroupMember {
  const GroupMember({
    required this.userId,
    required this.name,
    required this.email,
    this.photoUrl,
    this.isPending = false,
    this.isArchived = false,
    this.isDeletedAccount = false,
    this.archivedAt,
  });

  final String userId;
  final String name;
  final String email;
  final String? photoUrl;
  final bool isPending;
  final bool isArchived;
  final bool isDeletedAccount;
  final DateTime? archivedAt;

  bool get isActive => !isPending && !isArchived;

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'name': name,
    'email': email,
    'photoUrl': photoUrl,
    'isPending': isPending,
    'isArchived': isArchived,
    'isDeletedAccount': isDeletedAccount,
    'archivedAt': archivedAt?.toIso8601String(),
  };

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    // Una cuenta eliminada deja el nombre en blanco. Cae al mismo respaldo que
    // un nombre ausente, y asi nada que pinte la inicial se queda sin letra.
    final nombre = (map['name'] as String? ?? '').trim();
    return GroupMember(
      userId: map['userId'] as String,
      name: nombre.isEmpty ? 'Miembro' : nombre,
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      isPending: map['isPending'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      isDeletedAccount: map['isDeletedAccount'] as bool? ?? false,
      archivedAt: map['archivedAt'] == null ? null : _toDateTime(map['archivedAt']),
    );
  }

  GroupMember copyWith({
    String? userId,
    String? name,
    String? email,
    String? photoUrl,
    bool? isPending,
    bool? isArchived,
    bool? isDeletedAccount,
    DateTime? archivedAt,
  }) {
    return GroupMember(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      isPending: isPending ?? this.isPending,
      isArchived: isArchived ?? this.isArchived,
      isDeletedAccount: isDeletedAccount ?? this.isDeletedAccount,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  /// Version anonima de este miembro, para cuando su duenno borra la cuenta.
  ///
  /// El `userId` se conserva a proposito: los gastos apuntan a el, y quitarlo
  /// romperia el historico de saldos del resto del grupo. Lo que desaparece es
  /// lo que identifica a la persona —nombre, correo y foto—, que es justo lo
  /// que la politica de privacidad promete que desaparece.
  ///
  /// `copyWith` no sirve aqui: no puede poner `photoUrl` a nulo.
  GroupMember anonymized({DateTime? at}) => GroupMember(
    userId: userId,
    name: '',
    email: '',
    isPending: isPending,
    isArchived: true,
    isDeletedAccount: true,
    archivedAt: at ?? DateTime.now(),
  );
}

enum ExpenseRecordKind { expense, settlement }

enum AppNotificationType { expenseAdded, reimbursementRecorded, reimbursementRequested, groupSettlementRequested }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    this.groupId,
    this.expenseId,
    this.fromUserId,
    this.relatedUserId,
    this.amount,
    this.readAt,
  });

  final String id;
  final String userId;
  final AppNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final String? groupId;
  final String? expenseId;
  final String? fromUserId;
  final String? relatedUserId;
  final double? amount;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'type': type.name,
    'title': title,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'groupId': groupId,
    'expenseId': expenseId,
    'fromUserId': fromUserId,
    'relatedUserId': relatedUserId,
    'amount': amount,
    'readAt': readAt?.toIso8601String(),
  };

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      userId: map['userId'] as String? ?? '',
      type: AppNotificationType.values.firstWhere((entry) => entry.name == map['type'], orElse: () => AppNotificationType.expenseAdded),
      title: map['title'] as String? ?? 'Notificación',
      message: map['message'] as String? ?? '',
      createdAt: _toDateTime(map['createdAt']),
      groupId: map['groupId'] as String?,
      expenseId: map['expenseId'] as String?,
      fromUserId: map['fromUserId'] as String?,
      relatedUserId: map['relatedUserId'] as String?,
      amount: (map['amount'] as num?)?.toDouble(),
      readAt: map['readAt'] == null ? null : _toDateTime(map['readAt']),
    );
  }

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      createdAt: createdAt,
      groupId: groupId,
      expenseId: expenseId,
      fromUserId: fromUserId,
      relatedUserId: relatedUserId,
      amount: amount,
      readAt: readAt ?? this.readAt,
    );
  }
}

class PendingGroupMember {
  const PendingGroupMember({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory PendingGroupMember.fromMap(Map<String, dynamic> map) {
    return PendingGroupMember(id: map['id'] as String, name: map['name'] as String? ?? 'Persona invitada');
  }
}

/// Lo unico que se puede enseñar de un grupo a quien todavia no es miembro.
///
/// Vive en la coleccion `invites/{inviteCode}` de Firestore, separada de
/// `groups`, y es la pieza central de ADR-0009: antes, para enseñar «vas a
/// unirte a Roadtrip Costa, 4 miembros» habia que dejar leer el documento del
/// grupo, y ese documento lleva dentro **todos los gastos**. Cualquiera con una
/// cuenta podia leer el historial completo de cualquier grupo.
///
/// Aqui no hay gastos, ni correos, ni identificadores de usuario, ni el PIN. Si
/// alguien añade un campo a esta clase, que se pregunte antes si se lo enseñaria
/// a un desconocido, porque eso es exactamente lo que va a pasar.
class GroupInvitePreview {
  const GroupInvitePreview({
    required this.inviteCode,
    required this.groupId,
    required this.groupName,
    required this.iconKey,
    required this.currency,
    required this.memberCount,
    required this.openSlots,
    required this.isClosed,
    required this.allowAnonymousJoin,
    required this.updatedAt,
  });

  final String inviteCode;
  final String groupId;
  final String groupName;
  final String iconKey;
  final String currency;

  /// Cuanta gente hay dentro. Un numero, no la lista: los nombres y los correos
  /// de los miembros son datos del grupo.
  final int memberCount;

  /// Huecos reservados sin reclamar, para poder decir «soy Marta» al entrar.
  /// Solo id y nombre de pila, que es lo que el administrador escribio para que
  /// se viera.
  final List<PendingGroupMember> openSlots;

  final bool isClosed;
  final bool allowAnonymousJoin;
  final DateTime updatedAt;

  /// Las claves que las reglas de Firestore aceptan en `invites`. Si esto y la
  /// funcion `invitePublicKeys()` de `firestore.rules` dejan de coincidir, la
  /// escritura de la ficha empieza a fallar; hay una prueba que lo vigila.
  static const List<String> publicKeys = <String>[
    'groupId',
    'groupName',
    'iconKey',
    'currency',
    'memberCount',
    'pendingMembers',
    'isClosed',
    'allowAnonymousJoin',
    'updatedAt',
  ];

  factory GroupInvitePreview.fromGroup(ExpenseGroup group) {
    return GroupInvitePreview(
      inviteCode: group.inviteCode,
      groupId: group.id,
      groupName: group.name,
      iconKey: group.iconKey,
      currency: group.currency,
      memberCount: group.activeMembers.length,
      openSlots: group.openSlots,
      isClosed: group.isClosed,
      allowAnonymousJoin: group.allowAnonymousJoin,
      updatedAt: group.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'groupId': groupId,
    'groupName': groupName,
    'iconKey': iconKey,
    'currency': currency,
    'memberCount': memberCount,
    'pendingMembers': openSlots.map((entry) => entry.toMap()).toList(),
    'isClosed': isClosed,
    'allowAnonymousJoin': allowAnonymousJoin,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory GroupInvitePreview.fromMap(String inviteCode, Map<String, dynamic> map) {
    final rawSlots = map['pendingMembers'] as List<dynamic>? ?? const <dynamic>[];
    return GroupInvitePreview(
      inviteCode: inviteCode,
      groupId: map['groupId'] as String? ?? '',
      groupName: map['groupName'] as String? ?? 'Grupo',
      iconKey: map['iconKey'] as String? ?? 'groups',
      currency: map['currency'] as String? ?? 'EUR',
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 0,
      openSlots: rawSlots.map((entry) => PendingGroupMember.fromMap(Map<String, dynamic>.from(entry as Map))).toList(),
      isClosed: map['isClosed'] as bool? ?? false,
      allowAnonymousJoin: map['allowAnonymousJoin'] as bool? ?? false,
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  /// Si la ficha publicada ya no cuadra con el grupo, hay que reescribirla.
  bool matches(ExpenseGroup group) {
    final actual = GroupInvitePreview.fromGroup(group);
    return groupId == actual.groupId &&
        groupName == actual.groupName &&
        iconKey == actual.iconKey &&
        currency == actual.currency &&
        memberCount == actual.memberCount &&
        isClosed == actual.isClosed &&
        allowAnonymousJoin == actual.allowAnonymousJoin &&
        openSlots.length == actual.openSlots.length &&
        openSlots.every((slot) => actual.openSlots.any((other) => other.id == slot.id && other.name == slot.name));
  }
}

class ExpenseCategory {
  const ExpenseCategory({required this.id, required this.name, required this.iconKey, required this.colorHex, this.isDefault = false});

  final String id;
  final String name;
  final String iconKey;
  final String colorHex;
  final bool isDefault;

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'iconKey': iconKey, 'colorHex': colorHex, 'isDefault': isDefault};

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Categoría',
      iconKey: map['iconKey'] as String? ?? 'receipt',
      colorHex: map['colorHex'] as String? ?? '0xFFE4572E',
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }
}

class SplitAllocation {
  const SplitAllocation({required this.userId, required this.percentage});

  final String userId;
  final double percentage;

  Map<String, dynamic> toMap() => {'userId': userId, 'percentage': percentage};

  factory SplitAllocation.fromMap(Map<String, dynamic> map) {
    return SplitAllocation(userId: map['userId'] as String, percentage: (map['percentage'] as num?)?.toDouble() ?? 0);
  }

  SplitAllocation copyWith({String? userId, double? percentage}) {
    return SplitAllocation(userId: userId ?? this.userId, percentage: percentage ?? this.percentage);
  }
}

class ExpenseItem {
  const ExpenseItem({required this.id, required this.name, required this.amount, required this.categoryId, required this.allocations});

  final String id;
  final String name;
  final double amount;
  final String categoryId;
  final List<SplitAllocation> allocations;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'categoryId': categoryId,
    'allocations': allocations.map((entry) => entry.toMap()).toList(),
  };

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    final rawAllocations = map['allocations'] as List<dynamic>? ?? const [];
    return ExpenseItem(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Item',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      categoryId: map['categoryId'] as String? ?? 'food',
      allocations: rawAllocations.map((entry) => SplitAllocation.fromMap(Map<String, dynamic>.from(entry as Map))).toList(),
    );
  }

  ExpenseItem copyWith({String? id, String? name, double? amount, String? categoryId, List<SplitAllocation>? allocations}) {
    return ExpenseItem(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      allocations: allocations ?? this.allocations,
    );
  }
}

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.title,
    required this.payerId,
    required this.createdAt,
    required this.items,
    this.kind = ExpenseRecordKind.expense,
    this.note,
    this.receiptLabel,
    this.receiptStoragePath,
    this.receiptDownloadUrl,
  });

  final String id;
  final String title;
  final String payerId;
  final DateTime createdAt;
  final ExpenseRecordKind kind;
  final String? note;
  final String? receiptLabel;
  final String? receiptStoragePath;
  final String? receiptDownloadUrl;
  final List<ExpenseItem> items;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'payerId': payerId,
    'createdAt': createdAt.toIso8601String(),
    'kind': kind.name,
    'note': note,
    'receiptLabel': receiptLabel,
    'receiptStoragePath': receiptStoragePath,
    'receiptDownloadUrl': receiptDownloadUrl,
    'items': items.map((item) => item.toMap()).toList(),
  };

  factory ExpenseRecord.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? const [];
    return ExpenseRecord(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Gasto',
      payerId: map['payerId'] as String? ?? '',
      createdAt: _toDateTime(map['createdAt']),
      kind: ExpenseRecordKind.values.firstWhere((entry) => entry.name == map['kind'], orElse: () => ExpenseRecordKind.expense),
      note: map['note'] as String?,
      receiptLabel: map['receiptLabel'] as String?,
      receiptStoragePath: map['receiptStoragePath'] as String?,
      receiptDownloadUrl: map['receiptDownloadUrl'] as String?,
      items: rawItems.map((entry) => ExpenseItem.fromMap(Map<String, dynamic>.from(entry as Map))).toList(),
    );
  }

  ExpenseRecord copyWith({
    String? id,
    String? title,
    String? payerId,
    DateTime? createdAt,
    ExpenseRecordKind? kind,
    String? note,
    String? receiptLabel,
    String? receiptStoragePath,
    String? receiptDownloadUrl,
    List<ExpenseItem>? items,
  }) {
    return ExpenseRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      payerId: payerId ?? this.payerId,
      createdAt: createdAt ?? this.createdAt,
      kind: kind ?? this.kind,
      note: note ?? this.note,
      receiptLabel: receiptLabel ?? this.receiptLabel,
      receiptStoragePath: receiptStoragePath ?? this.receiptStoragePath,
      receiptDownloadUrl: receiptDownloadUrl ?? this.receiptDownloadUrl,
      items: items ?? this.items,
    );
  }

  ExpenseRecord zeroed() {
    return copyWith(items: items.map((item) => item.copyWith(amount: 0)).toList(growable: false));
  }
}

class ExpenseGroup {
  ExpenseGroup({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.currency,
    required this.ownerId,
    required this.adminIds,
    required this.inviteCode,
    required this.joinPin,
    required this.memberIds,
    required this.members,
    required this.pendingMembers,
    required this.allowAnonymousJoin,
    required this.customCategories,
    required this.expenses,
    required this.createdAt,
    required this.updatedAt,
    required this.isClosed,
    this.description,
    this.closedAt,
    this.claimedSlots = const <String, String>{},
  });

  final String id;
  final String name;
  final String iconKey;
  final String currency;
  final String ownerId;
  final List<String> adminIds;
  final String inviteCode;
  final String joinPin;
  final List<String> memberIds;
  final List<GroupMember> members;
  final List<PendingGroupMember> pendingMembers;

  /// Huecos reservados que ya ha reclamado alguien: `idDelHueco -> uid`.
  ///
  /// Antes, cuando alguien entraba y decia «soy Marta», el movil reescribia
  /// todos los gastos del grupo cambiando `pending:marta` por su uid. Eso exigia
  /// leer el grupo entero **antes de ser miembro**, que es justamente lo que
  /// ADR-0009 prohibe. Ahora la equivalencia se anota aqui y se resuelve al
  /// leer, en `GroupLedger`: una escritura de una linea en vez de reescribir el
  /// historial, y sin necesidad de leer nada.
  final Map<String, String> claimedSlots;
  final bool allowAnonymousJoin;
  final List<ExpenseCategory> customCategories;
  final List<ExpenseRecord> expenses;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isClosed;
  final String? description;
  final DateTime? closedAt;

  bool isAdmin(String userId) => ownerId == userId || adminIds.contains(userId);

  List<String> get allAdminIds => [ownerId, ...adminIds.where((entry) => entry != ownerId)];

  /// Miembros derivados.
  ///
  /// Antes eran getters que reconstruian la lista —y los `GroupMember`
  /// sinteticos de los invitados pendientes— en **cada acceso**. Se llaman
  /// dentro de `build`, dentro de bucles por gasto y dentro del calculo de
  /// saldos, asi que un grupo de diez personas con doscientos gastos generaba
  /// decenas de miles de listas por fotograma. Ahora se calculan una sola vez
  /// por instancia; como cada instantanea de Firestore crea un objeto nuevo, la
  /// cache se invalida sola cuando los datos cambian.
  /// Reclamos que de verdad cuentan: los que apuntan a alguien que esta en el
  /// grupo.
  ///
  /// Un reclamo colgado —porque la persona se borro la cuenta, o porque los
  /// datos llegaron a medias— no puede hacer desaparecer el hueco: si lo hiciera,
  /// la parte del gasto que le tocaba se quedaria sin nadie a quien cargarsela y
  /// los saldos dejarian de sumar cero. Se ignora y el hueco sigue libre.
  late final Map<String, String> effectiveClaimedSlots = Map<String, String>.unmodifiable(<String, String>{
    for (final entry in claimedSlots.entries)
      if (memberIds.contains(entry.value)) entry.key: entry.value,
  });

  late final List<GroupMember> _pendingAsMembers = List<GroupMember>.unmodifiable(
    pendingMembers
        .where((entry) => !effectiveClaimedSlots.containsKey(entry.id))
        .map((entry) => GroupMember(userId: 'pending:${entry.id}', name: entry.name, email: '', isPending: true)),
  );

  /// Huecos que siguen libres: los que nadie ha reclamado todavia.
  late final List<PendingGroupMember> openSlots = List<PendingGroupMember>.unmodifiable(
    pendingMembers.where((entry) => !effectiveClaimedSlots.containsKey(entry.id)),
  );

  late final List<GroupMember> activeMembers = List<GroupMember>.unmodifiable(members.where((member) => !member.isArchived));

  late final List<GroupMember> visibleMembers = List<GroupMember>.unmodifiable(<GroupMember>[...members, ..._pendingAsMembers]);

  late final List<GroupMember> selectableMembers = List<GroupMember>.unmodifiable(<GroupMember>[...activeMembers, ..._pendingAsMembers]);

  /// Cuanta gente se enseña que hay en el grupo.
  ///
  /// Cuenta los **activos**, no `members`, porque ahi dentro tambien estan los
  /// archivados: quien se salio, quien borro su cuenta y quien fue expulsado.
  /// Contandolos, un grupo de una persona con un hueco libre decia «3 miembros».
  int get totalDisplayedMembers => activeMembers.length + openSlots.length;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'iconKey': iconKey,
    'currency': currency,
    'ownerId': ownerId,
    'adminIds': adminIds,
    'inviteCode': inviteCode,
    'joinPin': joinPin,
    'memberIds': memberIds,
    'members': members.map((entry) => entry.toMap()).toList(),
    'pendingMembers': pendingMembers.map((entry) => entry.toMap()).toList(),
    'allowAnonymousJoin': allowAnonymousJoin,
    'customCategories': customCategories.map((entry) => entry.toMap()).toList(),
    'expenses': expenses.map((entry) => entry.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isClosed': isClosed,
    'closedAt': closedAt?.toIso8601String(),
    'claimedSlots': claimedSlots,
  };

  factory ExpenseGroup.fromMap(Map<String, dynamic> map) {
    final rawMembers = map['members'] as List<dynamic>? ?? const [];
    final rawPendingMembers = map['pendingMembers'] as List<dynamic>? ?? const [];
    final rawCategories = map['customCategories'] as List<dynamic>? ?? const [];
    final rawExpenses = map['expenses'] as List<dynamic>? ?? const [];
    final rawMemberIds = map['memberIds'] as List<dynamic>? ?? const [];
    final rawAdminIds = map['adminIds'] as List<dynamic>? ?? const [];

    return ExpenseGroup(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Grupo',
      description: map['description'] as String?,
      iconKey: map['iconKey'] as String? ?? 'groups',
      currency: map['currency'] as String? ?? 'EUR',
      ownerId: map['ownerId'] as String? ?? '',
      adminIds: rawAdminIds.map((entry) => entry.toString()).where((entry) => entry != (map['ownerId'] as String? ?? '')).toList(),
      inviteCode: map['inviteCode'] as String? ?? '',
      joinPin: normalizeGroupJoinPin(
        map['joinPin'] as String?,
        fallbackSeed: (map['id'] as String?) ?? (map['inviteCode'] as String?) ?? 'shardpay',
      ),
      memberIds: rawMemberIds.map((entry) => entry.toString()).toList(),
      members: rawMembers.map((entry) => GroupMember.fromMap(Map<String, dynamic>.from(entry as Map))).toList(),
      pendingMembers: rawPendingMembers.map((entry) => PendingGroupMember.fromMap(Map<String, dynamic>.from(entry as Map))).toList(),
      allowAnonymousJoin: map['allowAnonymousJoin'] as bool? ?? false,
      customCategories: rawCategories.map((entry) => ExpenseCategory.fromMap(Map<String, dynamic>.from(entry as Map))).toList(),
      expenses: rawExpenses.map((entry) => ExpenseRecord.fromMap(Map<String, dynamic>.from(entry as Map))).toList(),
      createdAt: _toDateTime(map['createdAt']),
      updatedAt: _toDateTime(map['updatedAt']),
      isClosed: map['isClosed'] as bool? ?? false,
      closedAt: map['closedAt'] == null ? null : _toDateTime(map['closedAt']),
      claimedSlots: <String, String>{
        for (final entry in (map['claimedSlots'] as Map<dynamic, dynamic>? ?? const <dynamic, dynamic>{}).entries)
          entry.key.toString(): entry.value.toString(),
      },
    );
  }

  ExpenseGroup copyWith({
    String? id,
    String? name,
    Object? description = _copyWithUnset,
    String? iconKey,
    String? currency,
    String? ownerId,
    List<String>? adminIds,
    String? inviteCode,
    String? joinPin,
    List<String>? memberIds,
    List<GroupMember>? members,
    List<PendingGroupMember>? pendingMembers,
    bool? allowAnonymousJoin,
    List<ExpenseCategory>? customCategories,
    List<ExpenseRecord>? expenses,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isClosed,
    Object? closedAt = _copyWithUnset,
    Map<String, String>? claimedSlots,
  }) {
    return ExpenseGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: identical(description, _copyWithUnset) ? this.description : description as String?,
      iconKey: iconKey ?? this.iconKey,
      currency: currency ?? this.currency,
      ownerId: ownerId ?? this.ownerId,
      adminIds: adminIds ?? this.adminIds,
      inviteCode: inviteCode ?? this.inviteCode,
      joinPin: joinPin ?? this.joinPin,
      memberIds: memberIds ?? this.memberIds,
      members: members ?? this.members,
      pendingMembers: pendingMembers ?? this.pendingMembers,
      allowAnonymousJoin: allowAnonymousJoin ?? this.allowAnonymousJoin,
      customCategories: customCategories ?? this.customCategories,
      expenses: expenses ?? this.expenses,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isClosed: isClosed ?? this.isClosed,
      closedAt: identical(closedAt, _copyWithUnset) ? this.closedAt : closedAt as DateTime?,
      claimedSlots: claimedSlots ?? this.claimedSlots,
    );
  }

  ExpenseGroup archived({DateTime? at}) {
    final archivedAt = at ?? DateTime.now();
    return copyWith(
      expenses: expenses.map((expense) => expense.zeroed()).toList(growable: false),
      isClosed: true,
      closedAt: archivedAt,
      updatedAt: archivedAt,
    );
  }
}
