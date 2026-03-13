import 'dart:async';

import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

import '../../core/expense_math.dart';
import '../../models/app_models.dart';
import '../app_repository.dart';

class FirebaseAppRepository implements AppRepository {
  FirebaseAppRepository({
    required auth.FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required GoogleSignIn googleSignIn,
  })  : _auth = auth,
        _firestore = firestore,
        _googleSignIn = googleSignIn;

  final auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  final _uuid = const Uuid();

  @override
  bool get isFirebaseBacked => true;

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) {
        return null;
      }
      return AppUser(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'Usuario',
        createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        photoUrl: firebaseUser.photoURL,
      );
    });
  }

  @override
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
    required bool register,
    String? displayName,
  }) async {
    try {
      final credential = register
          ? await _auth.createUserWithEmailAndPassword(email: email, password: password)
          : await _auth.signInWithEmailAndPassword(email: email, password: password);

      if (register && (displayName?.trim().isNotEmpty ?? false)) {
        await credential.user?.updateDisplayName(displayName!.trim());
      }

      final currentUser = _auth.currentUser!;
      return AppUser(
        id: currentUser.uid,
        email: currentUser.email ?? email,
        displayName: currentUser.displayName ?? displayName ?? email.split('@').first,
        createdAt: currentUser.metadata.creationTime ?? DateTime.now(),
        photoUrl: currentUser.photoURL,
      );
    } on auth.FirebaseAuthException catch (error) {
      throw StateError(_mapAuthException(error, register: register));
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw StateError('Has cancelado el inicio de sesión con Google.');
      }
      final authClient = await googleUser.authentication;

      final credential = auth.GoogleAuthProvider.credential(
        accessToken: authClient.accessToken,
        idToken: authClient.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;
      return AppUser(
        id: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? user.email?.split('@').first ?? 'Usuario',
        createdAt: user.metadata.creationTime ?? DateTime.now(),
        photoUrl: user.photoURL,
      );
    } on auth.FirebaseAuthException catch (error) {
      throw StateError(_mapAuthException(error, google: true));
    } catch (error) {
      throw StateError(_mapGoogleSignInError(error));
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  @override
  Future<void> deleteUserProfile(AppUser user) async {
    final groups = await _firestore.collection('groups').where('memberIds', arrayContains: user.id).get();
    for (final doc in groups.docs) {
      final group = ExpenseGroup.fromMap(doc.data());
      final remainingActive = group.activeMembers.where((entry) => entry.userId != user.id).toList();
      final ownerId = group.ownerId == user.id && remainingActive.isNotEmpty ? remainingActive.first.userId : group.ownerId;
      final adminIds = group.adminIds.where((entry) => entry != user.id).where((entry) => remainingActive.any((member) => member.userId == entry)).toList();
      final updatedMembers = group.members.map((entry) {
        if (entry.userId != user.id) {
          return entry;
        }
        return entry.copyWith(isArchived: true, isDeletedAccount: true, archivedAt: DateTime.now());
      }).toList();

      if (remainingActive.isEmpty && group.ownerId == user.id) {
        await doc.reference.delete();
        continue;
      }

      await doc.reference.set(
        group.copyWith(
          ownerId: ownerId,
          adminIds: adminIds,
          members: updatedMembers,
          memberIds: group.memberIds.where((entry) => entry != user.id).toList(),
          updatedAt: DateTime.now(),
        ).toMap(),
      );
    }

    try {
      await _firestore.collection('users').doc(user.id).delete();
    } catch (_) {}

    try {
      await _auth.currentUser?.delete();
    } on auth.FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        throw StateError('Para eliminar el perfil, vuelve a iniciar sesión y repite la operación.');
      }
      rethrow;
    }
  }

  @override
  Stream<List<ExpenseGroup>> watchGroups(String userId) {
    return _firestore
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseGroup.fromMap(doc.data()))
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
  }

  @override
  Stream<ExpenseGroup?> watchGroup(String groupId) {
    return _firestore.collection('groups').doc(groupId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return ExpenseGroup.fromMap(doc.data()!);
    });
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    return (() async* {
      try {
        await for (final snapshot in _notificationsRef(userId).orderBy('createdAt', descending: true).snapshots()) {
          yield snapshot.docs.map((doc) => AppNotification.fromMap(doc.data())).toList();
        }
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') {
          yield const <AppNotification>[];
          return;
        }
        rethrow;
      }
    })();
  }

  @override
  Future<ExpenseGroup?> previewInvite(String rawInvite) {
    return _resolveInvite(rawInvite);
  }

  @override
  Future<ExpenseGroup> createGroup({
    required AppUser owner,
    required String name,
    required String iconKey,
    required String currency,
    required List<PendingGroupMember> pendingMembers,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final group = ExpenseGroup(
      id: id,
      name: name.trim(),
      description: null,
      iconKey: iconKey,
      currency: currency,
      ownerId: owner.id,
      adminIds: const [],
      inviteCode: _uuid.v4().split('-').first.toUpperCase(),
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

    await _firestore.collection('groups').doc(id).set(group.toMap());
    return group;
  }

  @override
  Future<void> joinGroupByInvite({
    required AppUser user,
    required String rawInvite,
    String? pendingMemberId,
  }) async {
    final group = await _resolveInvite(rawInvite);
    if (group == null) {
      throw StateError('No se encontró ningún grupo con esa invitación.');
    }

    if (group.memberIds.contains(user.id)) {
      return;
    }
    if (group.isClosed) {
      throw StateError('El grupo está cerrado y no admite nuevas incorporaciones.');
    }

    PendingGroupMember? selectedSlot;
    if (pendingMemberId != null) {
      selectedSlot = group.pendingMembers.firstWhere((entry) => entry.id == pendingMemberId);
    }
    if (selectedSlot == null && !group.allowAnonymousJoin) {
      throw StateError('El administrador debe indicar qué persona se está uniendo o activar el acceso libre por enlace.');
    }

    final updated = group.copyWith(
      memberIds: [...group.memberIds, user.id],
      members: [
        ...group.members,
        GroupMember(userId: user.id, name: selectedSlot?.name ?? user.displayName, email: user.email, photoUrl: user.photoUrl),
      ],
      pendingMembers: group.pendingMembers.where((entry) => entry.id != pendingMemberId).toList(),
      updatedAt: DateTime.now(),
    );

    await _firestore.collection('groups').doc(group.id).set(updated.toMap());
  }

  @override
  Future<void> addExpense({required String groupId, required ExpenseRecord expense}) async {
    final docRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = ExpenseGroup.fromMap(snapshot.data()!);
      _ensureGroupAllowsExpense(current, expense);
      final updated = current.copyWith(
        expenses: [...current.expenses, expense],
        updatedAt: DateTime.now(),
      );
      transaction.set(docRef, updated.toMap());
    });
    final group = await _resolveGroup(groupId);
    if (group != null) {
      await _notifyExpenseEvent(group: group, expense: expense);
    }
  }

  @override
  Future<void> updateExpense({required String groupId, required ExpenseRecord expense}) async {
    final docRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = ExpenseGroup.fromMap(snapshot.data()!);
      _ensureGroupOpen(current);
      final updated = current.copyWith(
        expenses: current.expenses.map((entry) => entry.id == expense.id ? expense : entry).toList(),
        updatedAt: DateTime.now(),
      );
      transaction.set(docRef, updated.toMap());
    });
  }

  @override
  Future<void> deleteExpense({required String groupId, required String expenseId}) async {
    final docRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = ExpenseGroup.fromMap(snapshot.data()!);
      _ensureGroupOpen(current);
      final updated = current.copyWith(
        expenses: current.expenses.where((entry) => entry.id != expenseId).toList(),
        updatedAt: DateTime.now(),
      );
      transaction.set(docRef, updated.toMap());
    });
  }

  @override
  Future<void> upsertCategory({required String groupId, required ExpenseCategory category}) async {
    final docRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = ExpenseGroup.fromMap(snapshot.data()!);
      _ensureGroupOpen(current);
      final categories = [...current.customCategories];
      final index = categories.indexWhere((entry) => entry.id == category.id);
      if (index == -1) {
        categories.add(category);
      } else {
        categories[index] = category;
      }
      transaction.set(docRef, current.copyWith(customCategories: categories, updatedAt: DateTime.now()).toMap());
    });
  }

  @override
  Future<void> updateGroupJoinSettings({
    required String groupId,
    required String name,
    required String? description,
    required String iconKey,
    required List<PendingGroupMember> pendingMembers,
    required bool allowAnonymousJoin,
    required String currency,
  }) async {
    final docRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = ExpenseGroup.fromMap(snapshot.data()!);
      _ensureGroupOpen(current);
      transaction.set(
        docRef,
        current.copyWith(
          name: name.trim(),
          description: description?.trim().isEmpty ?? true ? null : description!.trim(),
          iconKey: iconKey,
          pendingMembers: pendingMembers,
          allowAnonymousJoin: allowAnonymousJoin,
          currency: currency,
          updatedAt: DateTime.now(),
        ).toMap(),
      );
    });
  }

  @override
  Future<void> transferGroupOwnership({
    required String groupId,
    required String requesterId,
    required String newOwnerId,
  }) async {
    final docRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = ExpenseGroup.fromMap(snapshot.data()!);
      if (current.ownerId != requesterId) {
        throw StateError('Solo la persona administradora puede reasignar la administración.');
      }
      _ensureGroupOpen(current);
      if (current.members.firstWhereOrNull((entry) => entry.userId == newOwnerId) == null) {
        throw StateError('La nueva persona administradora debe pertenecer al grupo.');
      }
      final nextAdmins = {
        ...current.adminIds.where((entry) => entry != newOwnerId),
        requesterId,
      }.where((entry) => entry != newOwnerId).toList();
      transaction.set(docRef, current.copyWith(ownerId: newOwnerId, adminIds: nextAdmins, updatedAt: DateTime.now()).toMap());
    });
  }

  @override
  Future<void> setGroupAdmins({
    required String groupId,
    required String requesterId,
    required List<String> adminIds,
  }) async {
    final docRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = ExpenseGroup.fromMap(snapshot.data()!);
      if (current.ownerId != requesterId) {
        throw StateError('Solo la persona administradora principal puede cambiar otros administradores.');
      }
      final validAdminIds = adminIds.where((entry) => entry != current.ownerId).where((entry) => current.activeMembers.any((member) => member.userId == entry)).toSet().toList();
      transaction.set(docRef, current.copyWith(adminIds: validAdminIds, updatedAt: DateTime.now()).toMap());
    });
  }

  @override
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    final docRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = ExpenseGroup.fromMap(snapshot.data()!);
      if (!current.memberIds.contains(userId)) {
        return;
      }

      final remainingMembers = current.activeMembers.where((entry) => entry.userId != userId).toList();
      final remainingIds = current.memberIds.where((entry) => entry != userId).toList();

      if (current.ownerId == userId && remainingMembers.isNotEmpty) {
        throw StateError('Antes de salir, reasigna la administración a otra persona del grupo.');
      }

      if (remainingMembers.isEmpty) {
        transaction.delete(docRef);
        return;
      }

      transaction.set(
        docRef,
        current.copyWith(
          adminIds: current.adminIds.where((entry) => entry != userId).toList(),
          memberIds: remainingIds,
          members: current.members.map((entry) {
            if (entry.userId != userId) {
              return entry;
            }
            return entry.copyWith(isArchived: true, archivedAt: DateTime.now());
          }).toList(),
          updatedAt: DateTime.now(),
        ).toMap(),
      );
    });
  }

  @override
  Future<void> setGroupClosed({required String groupId, required String requesterId, required bool isClosed}) async {
    final docRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = ExpenseGroup.fromMap(snapshot.data()!);
      if (!current.isAdmin(requesterId)) {
        throw StateError('Solo la persona administradora puede cerrar o abrir el grupo.');
      }
      transaction.set(
        docRef,
        current.copyWith(
          isClosed: isClosed,
          closedAt: isClosed ? DateTime.now() : null,
          updatedAt: DateTime.now(),
        ).toMap(),
      );
    });
  }

  @override
  Future<void> deleteGroup({
    required String groupId,
    required String requesterId,
  }) async {
    final docRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = ExpenseGroup.fromMap(snapshot.data()!);
      if (current.ownerId != requesterId) {
        throw StateError('Solo la persona administradora puede borrar el grupo.');
      }
      transaction.delete(docRef);
    });
  }

  @override
  Future<void> updateItemAllocations({
    required String groupId,
    required String expenseId,
    required String itemId,
    required List<SplitAllocation> allocations,
  }) async {
    final docRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = ExpenseGroup.fromMap(snapshot.data()!);
      _ensureGroupOpen(current);
      final updatedExpenses = current.expenses.map((expense) {
        if (expense.id != expenseId) {
          return expense;
        }

        return expense.copyWith(
          items: expense.items.map((item) {
            if (item.id != itemId) {
              return item;
            }
            return item.copyWith(allocations: allocations);
          }).toList(),
        );
      }).toList();

      transaction.set(docRef, current.copyWith(expenses: updatedExpenses, updatedAt: DateTime.now()).toMap());
    });
  }

  @override
  Future<void> requestReimbursement({required String groupId, required String requesterId, required String targetUserId, required double amount}) async {
    final group = await _resolveGroup(groupId);
    if (group == null) {
      throw StateError('Grupo no encontrado.');
    }
    final requester = group.members.firstWhereOrNull((entry) => entry.userId == requesterId);
    await _createNotification(
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
    final group = await _resolveGroup(groupId);
    if (group == null) {
      throw StateError('Grupo no encontrado.');
    }
    if (!group.isAdmin(requesterId)) {
      throw StateError('Solo la persona administradora puede solicitar el cierre de pagos.');
    }
    if (!group.isClosed) {
      throw StateError('Cierra el grupo antes de pedir que se salden las deudas.');
    }

    final balances = memberBalances(group);
    final admin = group.members.firstWhereOrNull((entry) => entry.userId == requesterId);
    final recipients = group.activeMembers.where((entry) => entry.userId != requesterId).where((entry) => -((balances[entry.userId] ?? 0)) > 0.009).toList();

    await Future.wait(
      recipients.map(
        (member) => _createNotification(
          AppNotification(
            id: _uuid.v4(),
            userId: member.userId,
            type: AppNotificationType.groupSettlementRequested,
            title: 'Cierre de cuentas pendiente',
            message: '${admin?.name ?? 'La persona administradora'} te pide saldar ${(-((balances[member.userId] ?? 0))).toStringAsFixed(2)} ${group.currency} en ${group.name}.',
            createdAt: DateTime.now(),
            groupId: group.id,
            fromUserId: requesterId,
            relatedUserId: member.userId,
            amount: -((balances[member.userId] ?? 0)),
          ),
        ),
      ),
    );

    return recipients.length;
  }

  @override
  Future<void> markNotificationRead({required String userId, required String notificationId}) async {
    final ref = _notificationsRef(userId).doc(notificationId);
    final snapshot = await ref.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }
    final notification = AppNotification.fromMap(snapshot.data()!);
    await ref.set(notification.copyWith(readAt: DateTime.now()).toMap());
  }

  @override
  Future<void> seedDemoData(AppUser user) async {}

  CollectionReference<Map<String, dynamic>> _notificationsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('notifications');
  }

  Future<ExpenseGroup?> _resolveGroup(String groupId) async {
    final snapshot = await _firestore.collection('groups').doc(groupId).get();
    return snapshot.data() == null ? null : ExpenseGroup.fromMap(snapshot.data()!);
  }

  void _ensureGroupOpen(ExpenseGroup group) {
    if (group.isClosed) {
      throw StateError('El grupo está cerrado. Solo se puede consultar hasta que la persona administradora lo reabra.');
    }
  }

  void _ensureGroupAllowsExpense(ExpenseGroup group, ExpenseRecord expense) {
    if (!group.isClosed || expense.kind == ExpenseRecordKind.settlement) {
      return;
    }
    throw StateError('El grupo está cerrado. Solo se pueden registrar liquidaciones hasta que la persona administradora lo reabra.');
  }

  Future<void> _createNotification(AppNotification notification) {
    return _notificationsRef(notification.userId).doc(notification.id).set(notification.toMap());
  }

  Future<void> _notifyExpenseEvent({required ExpenseGroup group, required ExpenseRecord expense}) async {
    final recipients = group.activeMembers.where((entry) => entry.userId != expense.payerId).toList();
    final payer = group.members.firstWhereOrNull((entry) => entry.userId == expense.payerId);

    if (expense.kind == ExpenseRecordKind.expense) {
      await Future.wait(
        recipients.map(
          (member) => _createNotification(
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
          ),
        ),
      );
      return;
    }

    final impactedUserIds = expense.items
        .expand((item) => item.allocations)
        .where((entry) => entry.userId != expense.payerId && !entry.userId.startsWith('pending:') && entry.percentage > 0)
        .map((entry) => entry.userId)
        .toSet();

    await Future.wait(
      impactedUserIds.map(
        (userId) => _createNotification(
          AppNotification(
            id: _uuid.v4(),
            userId: userId,
            type: AppNotificationType.reimbursementRecorded,
            title: 'Reembolso registrado',
            message: '${payer?.name ?? 'Una persona'} registró un reembolso de ${expense.items.fold<double>(0, (totalAmount, item) => totalAmount + item.amount).toStringAsFixed(2)} ${group.currency} en ${group.name}.',
            createdAt: DateTime.now(),
            groupId: group.id,
            expenseId: expense.id,
            fromUserId: expense.payerId,
            relatedUserId: userId,
          ),
        ),
      ),
    );
  }

  Future<ExpenseGroup?> _resolveInvite(String rawInvite) async {
    final value = rawInvite.trim();
    final reference = _parseInviteReference(value);
    if (reference != null) {
      final snapshot = await _firestore.collection('groups').doc(reference.groupId).get();
      if (snapshot.data() == null) {
        return null;
      }

      final group = ExpenseGroup.fromMap(snapshot.data()!);
      if (reference.token != null && reference.token!.isNotEmpty && group.inviteCode.toUpperCase() != reference.token!.toUpperCase()) {
        return null;
      }
      return group;
    }

    final query = await _firestore.collection('groups').where('inviteCode', isEqualTo: value.toUpperCase()).limit(1).get();
    if (query.docs.isEmpty) {
      return null;
    }
    return ExpenseGroup.fromMap(query.docs.first.data());
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

  String _mapAuthException(
    auth.FirebaseAuthException error, {
    bool register = false,
    bool google = false,
  }) {
    switch (error.code) {
      case 'invalid-email':
        return 'El email no tiene un formato valido.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Las credenciales no son correctas.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese email.';
      case 'weak-password':
        return 'La contraseña es demasiado débil. Usa al menos 6 caracteres.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'too-many-requests':
        return 'Se han hecho demasiados intentos. Espera un poco y vuelve a probar.';
      case 'network-request-failed':
        return 'No se pudo contactar con Firebase. Revisa la conexión e inténtalo otra vez.';
      case 'operation-not-allowed':
        if (google) {
          return 'El acceso con Google no está habilitado en Firebase Auth para este proyecto.';
        }
        return register
            ? 'El alta por email todavía no está habilitada en Firebase Auth para este proyecto.'
            : 'El acceso por email todavía no está habilitado en Firebase Auth para este proyecto.';
      case 'account-exists-with-different-credential':
        return 'Ya existe una cuenta con ese email usando otro método de acceso.';
      default:
        final message = error.message?.trim();
        if (message != null && message.isNotEmpty) {
          if (message.contains('CONFIGURATION_NOT_FOUND') || message.contains('BILLING_NOT_ENABLED')) {
            return 'Falta terminar la configuración de Firebase Auth en Google Cloud para este proyecto.';
          }
          return message;
        }
        return 'No se pudo completar la autenticación.';
    }
  }

  String _mapGoogleSignInError(Object error) {
    final raw = error.toString();
    if (raw.startsWith('Bad state: ')) {
      return raw.replaceFirst('Bad state: ', '');
    }
    if (raw.contains('10') || raw.contains('ApiException: 10')) {
      return 'Google Sign-In no está bien configurado para Android todavía. Revisa SHA-1 y el cliente OAuth.';
    }
    if (raw.contains('12500')) {
      return 'Google rechazó el acceso. Suele indicar que el proveedor aún no está habilitado en Firebase Auth.';
    }
    if (raw.contains('sign_in_failed')) {
      return 'Google Sign-In falló en el dispositivo. Revisa la cuenta de Google del móvil y la configuración del proyecto.';
    }
    return 'No se pudo iniciar sesión con Google.';
  }
}

class _InviteReference {
  const _InviteReference({required this.groupId, this.token});

  final String groupId;
  final String? token;
}