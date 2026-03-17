import 'dart:async';

import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import '../../core/expense_math.dart';
import '../../models/app_models.dart';
import '../app_repository.dart';

class MockAppRepository implements AppRepository {
  final _uuid = const Uuid();
  final _authController = StreamController<AppUser?>.broadcast(sync: true);
  final _groupsController = StreamController<void>.broadcast(sync: true);
  final _notificationsController = StreamController<void>.broadcast(sync: true);
  final Map<String, ExpenseGroup> _groups = {};
  final Map<String, List<AppNotification>> _notifications = {};
  AppUser? _currentUser;

  @override
  bool get isFirebaseBacked => false;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _currentUser;
    yield* _authController.stream;
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
    required bool register,
    String? displayName,
  }) async {
    final user = AppUser(
      id: _uuid.v4(),
      email: email,
      displayName: displayName?.trim().isNotEmpty == true ? displayName!.trim() : email.split('@').first,
      createdAt: DateTime.now(),
    );
    _currentUser = user;
    _authController.add(user);
    await seedDemoData(user);
    return user;
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    final user = AppUser(
      id: _uuid.v4(),
      email: 'demo@shardpay.app',
      displayName: 'Demo Rider',
      createdAt: DateTime.now(),
      photoUrl: null,
    );
    _currentUser = user;
    _authController.add(user);
    await seedDemoData(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authController.add(null);
  }

  @override
  Future<void> deleteUserProfile(AppUser user) async {
    final impactedGroups = _groups.values.where((group) => group.memberIds.contains(user.id)).map((group) => group.id).toList();
    for (final groupId in impactedGroups) {
      final group = _groups[groupId]!;
      final remainingActive = group.activeMembers.where((entry) => entry.userId != user.id).toList();
      if (remainingActive.isEmpty && group.ownerId == user.id) {
        _groups.remove(groupId);
        continue;
      }
      _groups[groupId] = group.copyWith(
        ownerId: group.ownerId == user.id && remainingActive.isNotEmpty ? remainingActive.first.userId : group.ownerId,
        adminIds: group.adminIds.where((entry) => entry != user.id).where((entry) => remainingActive.any((member) => member.userId == entry)).toList(),
        members: group.members.map((entry) {
          if (entry.userId != user.id) {
            return entry;
          }
          return entry.copyWith(isArchived: true, isDeletedAccount: true, archivedAt: DateTime.now());
        }).toList(),
        memberIds: group.memberIds.where((entry) => entry != user.id).toList(),
        updatedAt: DateTime.now(),
      );
    }

    _notifications.remove(user.id);
    _currentUser = null;
    _groupsController.add(null);
    _notificationsController.add(null);
    _authController.add(null);
  }

  @override
  Stream<List<ExpenseGroup>> watchGroups(String userId) async* {
    yield _groups.values.where((group) => group.memberIds.contains(userId)).sorted((a, b) => b.updatedAt.compareTo(a.updatedAt)).toList();
    await for (final _ in _groupsController.stream) {
      yield _groups.values.where((group) => group.memberIds.contains(userId)).sorted((a, b) => b.updatedAt.compareTo(a.updatedAt)).toList();
    }
  }

  @override
  Stream<ExpenseGroup?> watchGroup(String groupId) async* {
    yield _groups[groupId];
    await for (final _ in _groupsController.stream) {
      yield _groups[groupId];
    }
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) async* {
    yield [...(_notifications[userId] ?? const <AppNotification>[])]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await for (final _ in _notificationsController.stream) {
      yield [...(_notifications[userId] ?? const <AppNotification>[])]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  @override
  Future<ExpenseGroup?> previewInvite(String rawInvite) async {
    final value = rawInvite.trim();
    final reference = _parseInviteReference(value);
    if (reference != null) {
      final group = _groups[reference.groupId];
      if (group == null) {
        return null;
      }
      if (reference.token != null && reference.token!.isNotEmpty && group.inviteCode.toUpperCase() != reference.token!.toUpperCase()) {
        return null;
      }
      return group;
    }

    return _groups.values.firstWhereOrNull((entry) => entry.inviteCode == value.toUpperCase());
  }

  _InviteReference? _parseInviteReference(String rawInvite) {
    final uri = Uri.tryParse(rawInvite);

    if (uri != null && uri.queryParameters.containsKey('group')) {
      final groupId = uri.queryParameters['group'];
      if (groupId != null && groupId.isNotEmpty) {
        return _InviteReference(
          groupId: groupId,
          token: uri.queryParameters['token']?.trim(),
        );
      }
    }

    if (rawInvite.contains(':')) {
      final parts = rawInvite.split(':');
      if (parts.length == 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
        return _InviteReference(groupId: parts.first, token: parts.last);
      }
    }

    return null;
  }

  @override
  Future<ExpenseGroup> createGroup({required AppUser owner, required String name, required String iconKey, required String currency, required List<PendingGroupMember> pendingMembers}) async {
    final now = DateTime.now();
    final group = ExpenseGroup(
      id: _uuid.v4(),
      name: name.trim(),
      description: null,
      iconKey: iconKey,
      currency: currency,
      ownerId: owner.id,
      adminIds: const [],
      inviteCode: _uuid.v4().split('-').first.toUpperCase(),
      joinPin: generateGroupJoinPin(),
      memberIds: [owner.id],
      members: [GroupMember(userId: owner.id, name: owner.displayName, email: owner.email, photoUrl: owner.photoUrl)],
      pendingMembers: pendingMembers,
      allowAnonymousJoin: false,
      customCategories: const [],
      expenses: const [],
      createdAt: now,
      updatedAt: now,
      isClosed: false,
    );
    _groups[group.id] = group;
    _groupsController.add(null);
    return group;
  }

  @override
  Future<void> joinGroupByInvite({
    required AppUser user,
    required String rawInvite,
    required String joinPin,
    String? pendingMemberId,
  }) async {
    final group = await previewInvite(rawInvite);

    if (group == null) {
      throw StateError('Invitación no encontrada.');
    }
    if (group.isClosed) {
      throw StateError('El grupo está cerrado y no admite nuevas incorporaciones.');
    }
    if (group.joinPin != joinPin.trim()) {
      throw StateError('El PIN del grupo no es correcto.');
    }
    if (group.memberIds.contains(user.id)) {
      return;
    }

    PendingGroupMember? selectedSlot;
    if (pendingMemberId != null) {
      selectedSlot = group.pendingMembers.firstWhereOrNull((entry) => entry.id == pendingMemberId);
    }
    if (selectedSlot == null && !group.allowAnonymousJoin) {
      throw StateError('El administrador debe indicar qué persona se está uniendo o activar el acceso libre por enlace.');
    }

    final memberName = selectedSlot?.name ?? user.displayName;
    final pendingUserId = selectedSlot == null ? null : 'pending:${selectedSlot.id}';

    _groups[group.id] = group.copyWith(
      memberIds: [...group.memberIds, user.id],
      members: [...group.members, GroupMember(userId: user.id, name: memberName, email: user.email, photoUrl: user.photoUrl)],
      pendingMembers: group.pendingMembers.where((entry) => entry.id != pendingMemberId).toList(),
      expenses: pendingUserId == null ? group.expenses : _rebindPendingMemberReferences(group.expenses, pendingUserId, user.id),
      updatedAt: DateTime.now(),
    );
    _groupsController.add(null);
  }

  @override
  Future<void> addExpense({required String groupId, required ExpenseRecord expense}) async {
    final group = _groups[groupId]!;
    _ensureGroupAllowsExpense(group, expense);
    _groups[groupId] = group.copyWith(
      expenses: [...group.expenses, expense],
      updatedAt: DateTime.now(),
    );
    await _notifyExpenseEvent(group: _groups[groupId]!, expense: expense);
    _groupsController.add(null);
  }

  @override
  Future<void> updateExpense({required String groupId, required ExpenseRecord expense}) async {
    final group = _groups[groupId]!;
    _ensureGroupOpen(group);
    _groups[groupId] = group.copyWith(
      expenses: group.expenses.map((entry) => entry.id == expense.id ? expense : entry).toList(),
      updatedAt: DateTime.now(),
    );
    _groupsController.add(null);
  }

  @override
  Future<void> deleteExpense({required String groupId, required String expenseId}) async {
    final group = _groups[groupId]!;
    _ensureGroupOpen(group);
    _groups[groupId] = group.copyWith(
      expenses: group.expenses.where((entry) => entry.id != expenseId).toList(),
      updatedAt: DateTime.now(),
    );
    _groupsController.add(null);
  }

  @override
  Future<void> upsertCategory({required String groupId, required ExpenseCategory category}) async {
    final group = _groups[groupId]!;
    _ensureGroupOpen(group);
    final categories = [...group.customCategories];
    final index = categories.indexWhere((entry) => entry.id == category.id);
    if (index == -1) {
      categories.add(category);
    } else {
      categories[index] = category;
    }
    _groups[groupId] = group.copyWith(customCategories: categories, updatedAt: DateTime.now());
    _groupsController.add(null);
  }

  @override
  Future<void> updateGroupJoinSettings({
    required String groupId,
    required String name,
    required String? description,
    required String iconKey,
    required List<GroupMember> members,
    required List<PendingGroupMember> pendingMembers,
    required bool allowAnonymousJoin,
    required String currency,
    required String joinPin,
  }) async {
    final group = _groups[groupId]!;
    _ensureGroupOpen(group);
    _groups[groupId] = group.copyWith(
      name: name.trim(),
      description: description?.trim().isEmpty ?? true ? null : description!.trim(),
      iconKey: iconKey,
      members: members,
      memberIds: members.map((entry) => entry.userId).toList(growable: false),
      pendingMembers: pendingMembers,
      allowAnonymousJoin: allowAnonymousJoin,
      currency: currency,
      joinPin: joinPin,
      updatedAt: DateTime.now(),
    );
    _groupsController.add(null);
  }

  @override
  Future<void> transferGroupOwnership({
    required String groupId,
    required String requesterId,
    required String newOwnerId,
  }) async {
    final group = _groups[groupId]!;
    if (group.ownerId != requesterId) {
      throw StateError('Solo la persona administradora puede reasignar la administración.');
    }
    _ensureGroupOpen(group);
    if (group.members.firstWhereOrNull((entry) => entry.userId == newOwnerId) == null) {
      throw StateError('La nueva persona administradora debe pertenecer al grupo.');
    }
    final nextAdmins = {
      ...group.adminIds.where((entry) => entry != newOwnerId),
      requesterId,
    }.where((entry) => entry != newOwnerId).toList();
    _groups[groupId] = group.copyWith(ownerId: newOwnerId, adminIds: nextAdmins, updatedAt: DateTime.now());
    _groupsController.add(null);
  }

  @override
  Future<void> setGroupAdmins({
    required String groupId,
    required String requesterId,
    required List<String> adminIds,
  }) async {
    final group = _groups[groupId]!;
    if (group.ownerId != requesterId) {
      throw StateError('Solo la persona administradora principal puede cambiar otros administradores.');
    }
    final validAdminIds = adminIds.where((entry) => entry != group.ownerId).where((entry) => group.activeMembers.any((member) => member.userId == entry)).toSet().toList();
    _groups[groupId] = group.copyWith(adminIds: validAdminIds, updatedAt: DateTime.now());
    _groupsController.add(null);
  }

  @override
  Future<void> setGroupClosed({required String groupId, required String requesterId, required bool isClosed}) async {
    final group = _groups[groupId]!;
    if (!group.isAdmin(requesterId)) {
      throw StateError('Solo la persona administradora puede cerrar o abrir el grupo.');
    }
    final now = DateTime.now();
    _groups[groupId] = isClosed
        ? group.archived(at: now)
        : group.copyWith(
            isClosed: false,
            closedAt: null,
            updatedAt: now,
          );
    _groupsController.add(null);
  }

  @override
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    final group = _groups[groupId]!;
    if (!group.memberIds.contains(userId)) {
      return;
    }

    final remainingMembers = group.activeMembers.where((entry) => entry.userId != userId).toList();
    final remainingIds = group.memberIds.where((entry) => entry != userId).toList();

    if (group.ownerId == userId && remainingMembers.isNotEmpty) {
      throw StateError('Antes de salir, reasigna la administración a otra persona del grupo.');
    }

    if (remainingMembers.isEmpty) {
      _groups.remove(groupId);
      _groupsController.add(null);
      return;
    }

    _groups[groupId] = group.copyWith(
      adminIds: group.adminIds.where((entry) => entry != userId).toList(),
      memberIds: remainingIds,
      members: group.members.map((entry) {
        if (entry.userId != userId) {
          return entry;
        }
        return entry.copyWith(isArchived: true, archivedAt: DateTime.now());
      }).toList(),
      updatedAt: DateTime.now(),
    );
    _groupsController.add(null);
  }

  @override
  Future<void> deleteGroup({
    required String groupId,
    required String requesterId,
  }) async {
    final group = _groups[groupId]!;
    if (group.ownerId != requesterId) {
      throw StateError('Solo la persona administradora puede borrar el grupo.');
    }
    _groups.remove(groupId);
    _groupsController.add(null);
  }

  @override
  Future<void> updateItemAllocations({
    required String groupId,
    required String expenseId,
    required String itemId,
    required List<SplitAllocation> allocations,
  }) async {
    final group = _groups[groupId]!;
    _ensureGroupOpen(group);
    _groups[groupId] = group.copyWith(
      expenses: group.expenses.map((expense) {
        if (expense.id != expenseId) {
          return expense;
        }
        return expense.copyWith(
          items: expense.items.map((item) => item.id == itemId ? item.copyWith(allocations: allocations) : item).toList(),
        );
      }).toList(),
      updatedAt: DateTime.now(),
    );
    _groupsController.add(null);
  }

  @override
  Future<void> requestReimbursement({required String groupId, required String requesterId, required String targetUserId, required double amount}) async {
    final group = _groups[groupId]!;
    final targetMember = group.visibleMembers.firstWhereOrNull((entry) => entry.userId == targetUserId);
    if (targetUserId.startsWith('pending:') || (targetMember?.isPending ?? false) || (targetMember?.isDeletedAccount ?? false)) {
      return;
    }
    final requester = group.members.firstWhereOrNull((entry) => entry.userId == requesterId);
    _pushNotification(
      AppNotification(
        id: _uuid.v4(),
        userId: targetUserId,
        type: AppNotificationType.reimbursementRequested,
        title: 'Solicitud de reembolso',
        message: '${requester?.name ?? 'Una persona'} solicita ${amount.toStringAsFixed(2)} ${group.currency} en ${group.name}.',
        createdAt: DateTime.now(),
        groupId: group.id,
        fromUserId: requesterId,
        relatedUserId: targetUserId,
        amount: amount,
      ),
    );
  }

  @override
  Future<int> requestGroupSettlementNotifications({required String groupId, required String requesterId}) async {
    final group = _groups[groupId]!;
    if (!group.isAdmin(requesterId)) {
      throw StateError('Solo la persona administradora puede solicitar el cierre de pagos.');
    }

    final edges = settlementEdges(group, activeAccountsOnly: false);
    final balances = memberBalances(group);
    final admin = group.members.firstWhereOrNull((entry) => entry.userId == requesterId);
    final recipientIds = edges.expand((edge) => [edge.fromUserId, edge.toUserId]).where((userId) => userId != requesterId && !userId.startsWith('pending:')).toSet();
    var sent = 0;

    for (final member in group.visibleMembers.where((entry) => recipientIds.contains(entry.userId) && !entry.isPending && !entry.isDeletedAccount)) {
      final balance = balances[member.userId] ?? 0;
      final amount = balance.abs();
      if (amount <= 0.009) {
        continue;
      }
      sent += 1;
      _pushNotification(
        AppNotification(
          id: _uuid.v4(),
          userId: member.userId,
          type: AppNotificationType.groupSettlementRequested,
          title: 'Liquidación del grupo',
          message: balance < 0
              ? '${admin?.name ?? 'La persona administradora'} te pide saldar ${amount.toStringAsFixed(2)} ${group.currency} en ${group.name}.'
              : '${admin?.name ?? 'La persona administradora'} te avisa de que tienes ${amount.toStringAsFixed(2)} ${group.currency} a favor en ${group.name}.',
          createdAt: DateTime.now(),
          groupId: group.id,
          fromUserId: requesterId,
          relatedUserId: member.userId,
          amount: amount,
        ),
      );
    }

    return sent;
  }

  @override
  Future<void> markNotificationRead({required String userId, required String notificationId}) async {
    final items = [...(_notifications[userId] ?? const <AppNotification>[])];
    final index = items.indexWhere((entry) => entry.id == notificationId);
    if (index == -1) {
      return;
    }
    items[index] = items[index].copyWith(readAt: DateTime.now());
    _notifications[userId] = items;
    _notificationsController.add(null);
  }

  @override
  Future<void> seedDemoData(AppUser user) async {
    if (_groups.values.any((group) => group.memberIds.contains(user.id))) {
      return;
    }

    final partner = GroupMember(userId: 'friend-1', name: 'Noa', email: 'noa@example.com');
    final squad = [
      GroupMember(userId: user.id, name: user.displayName, email: user.email, photoUrl: user.photoUrl),
      partner,
      const GroupMember(userId: 'friend-2', name: 'Leo', email: 'leo@example.com'),
    ];

    final tripId = _uuid.v4();
    final weekendId = _uuid.v4();

    final tripExpenses = [
      ExpenseRecord(
        id: _uuid.v4(),
        title: 'Cena del viernes',
        payerId: user.id,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        items: [
          ExpenseItem(id: _uuid.v4(), name: 'Sushi combo', amount: 42.50, categoryId: 'food', allocations: equalAllocations(squad)),
          ExpenseItem(id: _uuid.v4(), name: 'Postres', amount: 14.20, categoryId: 'fun', allocations: equalAllocations([squad[0], squad[1]])),
        ],
      ),
      ExpenseRecord(
        id: _uuid.v4(),
        title: 'Gasolina',
        payerId: 'friend-2',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        items: [
          ExpenseItem(id: _uuid.v4(), name: 'Depósito', amount: 63.90, categoryId: 'transport', allocations: equalAllocations(squad)),
        ],
      ),
    ];

    _groups[tripId] = ExpenseGroup(
      id: tripId,
      name: 'Roadtrip Costa',
      description: 'Gastos del viaje, comida y coche compartido.',
      iconKey: 'trip',
      currency: 'EUR',
      ownerId: user.id,
      adminIds: const [],
      inviteCode: 'ROAD24',
      joinPin: '2401',
      memberIds: squad.map((member) => member.userId).toList(),
      members: squad,
      pendingMembers: const [
        PendingGroupMember(id: 'slot_1', name: 'Alex'),
        PendingGroupMember(id: 'slot_2', name: 'Brais'),
      ],
      allowAnonymousJoin: false,
      customCategories: const [
        ExpenseCategory(id: 'surf', name: 'Surf', iconKey: 'bolt', colorHex: '0xFF1B998B'),
      ],
      expenses: tripExpenses,
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
      isClosed: false,
    );

    _groups[weekendId] = ExpenseGroup(
      id: weekendId,
      name: 'Piso Centro',
      description: 'Compras, casa y gastos recurrentes del piso.',
      iconKey: 'home',
      currency: 'EUR',
      ownerId: user.id,
      adminIds: const [],
      inviteCode: 'PISO777',
      joinPin: '7710',
      memberIds: [user.id, partner.userId],
      members: [squad.first, partner],
      pendingMembers: const [],
      allowAnonymousJoin: true,
      customCategories: const [
        ExpenseCategory(id: 'cleaning', name: 'Limpieza', iconKey: 'home', colorHex: '0xFF3A86FF'),
      ],
      expenses: [
        ExpenseRecord(
          id: _uuid.v4(),
          title: 'Compra semanal',
          payerId: partner.userId,
          createdAt: DateTime.now().subtract(const Duration(days: 4)),
          note: 'Demo local para validar flujo sin Firebase.',
          items: [
            ExpenseItem(id: _uuid.v4(), name: 'Verdura', amount: 18.40, categoryId: 'groceries', allocations: equalAllocations([squad.first, partner])),
            ExpenseItem(id: _uuid.v4(), name: 'Café', amount: 6.80, categoryId: 'coffee', allocations: [
              SplitAllocation(userId: user.id, percentage: 100),
              SplitAllocation(userId: partner.userId, percentage: 0),
            ]),
          ],
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      isClosed: false,
    );

    _groupsController.add(null);
  }

  List<ExpenseRecord> _rebindPendingMemberReferences(List<ExpenseRecord> expenses, String pendingUserId, String actualUserId) {
    final legacyPendingUserId = pendingUserId.startsWith('pending:') ? pendingUserId.substring('pending:'.length) : pendingUserId;

    return expenses
        .map(
          (expense) => expense.copyWith(
            payerId: expense.payerId == pendingUserId || expense.payerId == legacyPendingUserId ? actualUserId : expense.payerId,
            items: expense.items
                .map(
                  (item) => item.copyWith(
                    allocations: _mergeAllocations(item.allocations, pendingUserId, actualUserId),
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  List<SplitAllocation> _mergeAllocations(List<SplitAllocation> allocations, String pendingUserId, String actualUserId) {
    final legacyPendingUserId = pendingUserId.startsWith('pending:') ? pendingUserId.substring('pending:'.length) : pendingUserId;
    final orderedUserIds = <String>[];
    final percentagesByUser = <String, double>{};

    for (final allocation in allocations) {
      final targetUserId = allocation.userId == pendingUserId || allocation.userId == legacyPendingUserId ? actualUserId : allocation.userId;
      if (!percentagesByUser.containsKey(targetUserId)) {
        orderedUserIds.add(targetUserId);
      }
      percentagesByUser[targetUserId] = (percentagesByUser[targetUserId] ?? 0) + allocation.percentage;
    }

    return orderedUserIds
        .map(
          (userId) => SplitAllocation(
            userId: userId,
            percentage: double.parse((percentagesByUser[userId] ?? 0).toStringAsFixed(2)),
          ),
        )
        .where((allocation) => allocation.percentage > 0)
        .toList(growable: false);
  }

  void _ensureGroupOpen(ExpenseGroup group) {
    if (group.isClosed) {
      throw StateError('El grupo está cerrado. Solo se puede consultar hasta que la persona administradora lo reabra.');
    }
  }

  void _ensureGroupAllowsExpense(ExpenseGroup group, ExpenseRecord expense) {
    if (!group.isClosed) {
      return;
    }
    throw StateError('El grupo está cerrado. Reábrelo antes de registrar pagos o nuevos gastos.');
  }

  void _pushNotification(AppNotification notification) {
    final items = [...(_notifications[notification.userId] ?? const <AppNotification>[])];
    items.add(notification);
    _notifications[notification.userId] = items;
    _notificationsController.add(null);
  }

  Future<void> _notifyExpenseEvent({required ExpenseGroup group, required ExpenseRecord expense}) async {
    final payer = group.members.firstWhereOrNull((entry) => entry.userId == expense.payerId);
    if (expense.kind == ExpenseRecordKind.expense) {
      for (final member in group.activeMembers.where((entry) => entry.userId != expense.payerId && !entry.isDeletedAccount && !entry.userId.startsWith('pending:'))) {
        _pushNotification(
          AppNotification(
            id: _uuid.v4(),
            userId: member.userId,
            type: AppNotificationType.expenseAdded,
            title: 'Nuevo gasto',
            message: '${payer?.name ?? 'Una persona'} añadió "${expense.title}" en ${group.name}.',
            createdAt: DateTime.now(),
            groupId: group.id,
            expenseId: expense.id,
            fromUserId: expense.payerId,
          ),
        );
      }
      return;
    }

    final total = expense.items.fold<double>(0, (totalAmount, item) => totalAmount + item.amount);
    final impactedUserIds = expense.items
        .expand((item) => item.allocations)
        .where((entry) => entry.userId != expense.payerId && !entry.userId.startsWith('pending:') && entry.percentage > 0)
        .map((entry) => entry.userId)
        .toSet();

    for (final userId in impactedUserIds) {
      _pushNotification(
        AppNotification(
          id: _uuid.v4(),
          userId: userId,
          type: AppNotificationType.reimbursementRecorded,
          title: 'Reembolso registrado',
          message: '${payer?.name ?? 'Una persona'} registró un reembolso de ${total.toStringAsFixed(2)} ${group.currency} en ${group.name}.',
          createdAt: DateTime.now(),
          groupId: group.id,
          expenseId: expense.id,
          fromUserId: expense.payerId,
          relatedUserId: userId,
        ),
      );
    }
  }
}

class _InviteReference {
  const _InviteReference({required this.groupId, this.token});

  final String groupId;
  final String? token;
}
