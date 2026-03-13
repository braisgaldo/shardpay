import 'package:cloud_firestore/cloud_firestore.dart';

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

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.photoUrl,
  });

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
    return GroupMember(
      userId: map['userId'] as String,
      name: map['name'] as String? ?? 'Miembro',
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
      type: AppNotificationType.values.firstWhere(
        (entry) => entry.name == map['type'],
        orElse: () => AppNotificationType.expenseAdded,
      ),
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
  const PendingGroupMember({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
      };

  factory PendingGroupMember.fromMap(Map<String, dynamic> map) {
    return PendingGroupMember(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Persona invitada',
    );
  }
}

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorHex,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String iconKey;
  final String colorHex;
  final bool isDefault;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'colorHex': colorHex,
        'isDefault': isDefault,
      };

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

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'percentage': percentage,
      };

  factory SplitAllocation.fromMap(Map<String, dynamic> map) {
    return SplitAllocation(
      userId: map['userId'] as String,
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0,
    );
  }

  SplitAllocation copyWith({String? userId, double? percentage}) {
    return SplitAllocation(
      userId: userId ?? this.userId,
      percentage: percentage ?? this.percentage,
    );
  }
}

class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.allocations,
  });

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
    final rawAllocations = (map['allocations'] as List<dynamic>? ?? const []);
    return ExpenseItem(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Item',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      categoryId: map['categoryId'] as String? ?? 'food',
      allocations: rawAllocations
          .map((entry) => SplitAllocation.fromMap(Map<String, dynamic>.from(entry as Map)))
          .toList(),
    );
  }

  ExpenseItem copyWith({
    String? id,
    String? name,
    double? amount,
    String? categoryId,
    List<SplitAllocation>? allocations,
  }) {
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
    final rawItems = (map['items'] as List<dynamic>? ?? const []);
    return ExpenseRecord(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Gasto',
      payerId: map['payerId'] as String? ?? '',
      createdAt: _toDateTime(map['createdAt']),
      kind: ExpenseRecordKind.values.firstWhere(
        (entry) => entry.name == map['kind'],
        orElse: () => ExpenseRecordKind.expense,
      ),
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
}

class ExpenseGroup {
  const ExpenseGroup({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.currency,
    required this.ownerId,
    required this.adminIds,
    required this.inviteCode,
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
  });

  final String id;
  final String name;
  final String iconKey;
  final String currency;
  final String ownerId;
  final List<String> adminIds;
  final String inviteCode;
  final List<String> memberIds;
  final List<GroupMember> members;
  final List<PendingGroupMember> pendingMembers;
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

  List<GroupMember> get activeMembers => members.where((member) => !member.isArchived).toList();

  List<GroupMember> get visibleMembers => [
        ...members,
        ...pendingMembers.map(
          (entry) => GroupMember(
            userId: 'pending:${entry.id}',
            name: entry.name,
            email: '',
            isPending: true,
          ),
        ),
      ];

  List<GroupMember> get selectableMembers => [
        ...activeMembers,
        ...pendingMembers.map(
          (entry) => GroupMember(
            userId: 'pending:${entry.id}',
            name: entry.name,
            email: '',
            isPending: true,
          ),
        ),
      ];

  int get totalDisplayedMembers => members.length + pendingMembers.length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
      'description': description,
      'iconKey': iconKey,
        'currency': currency,
        'ownerId': ownerId,
        'adminIds': adminIds,
        'inviteCode': inviteCode,
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
      };

  factory ExpenseGroup.fromMap(Map<String, dynamic> map) {
    final rawMembers = (map['members'] as List<dynamic>? ?? const []);
    final rawPendingMembers = (map['pendingMembers'] as List<dynamic>? ?? const []);
    final rawCategories = (map['customCategories'] as List<dynamic>? ?? const []);
    final rawExpenses = (map['expenses'] as List<dynamic>? ?? const []);
    final rawMemberIds = (map['memberIds'] as List<dynamic>? ?? const []);
    final rawAdminIds = (map['adminIds'] as List<dynamic>? ?? const []);

    return ExpenseGroup(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Grupo',
      description: map['description'] as String?,
      iconKey: map['iconKey'] as String? ?? 'groups',
      currency: map['currency'] as String? ?? 'EUR',
      ownerId: map['ownerId'] as String? ?? '',
      adminIds: rawAdminIds.map((entry) => entry.toString()).where((entry) => entry != (map['ownerId'] as String? ?? '')).toList(),
      inviteCode: map['inviteCode'] as String? ?? '',
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
    );
  }

  ExpenseGroup copyWith({
    String? id,
    String? name,
    String? description,
    String? iconKey,
    String? currency,
    String? ownerId,
    List<String>? adminIds,
    String? inviteCode,
    List<String>? memberIds,
    List<GroupMember>? members,
    List<PendingGroupMember>? pendingMembers,
    bool? allowAnonymousJoin,
    List<ExpenseCategory>? customCategories,
    List<ExpenseRecord>? expenses,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isClosed,
    DateTime? closedAt,
  }) {
    return ExpenseGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconKey: iconKey ?? this.iconKey,
      currency: currency ?? this.currency,
      ownerId: ownerId ?? this.ownerId,
      adminIds: adminIds ?? this.adminIds,
      inviteCode: inviteCode ?? this.inviteCode,
      memberIds: memberIds ?? this.memberIds,
      members: members ?? this.members,
      pendingMembers: pendingMembers ?? this.pendingMembers,
      allowAnonymousJoin: allowAnonymousJoin ?? this.allowAnonymousJoin,
      customCategories: customCategories ?? this.customCategories,
      expenses: expenses ?? this.expenses,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isClosed: isClosed ?? this.isClosed,
      closedAt: closedAt ?? this.closedAt,
    );
  }
}