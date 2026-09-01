import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

import '../../core/expense_math.dart';
import '../../core/join_proof.dart';
import '../../models/app_models.dart';
import '../app_repository.dart';

class FirebaseAppRepository implements AppRepository {
  FirebaseAppRepository({required auth.FirebaseAuth auth, required FirebaseFirestore firestore, required GoogleSignIn googleSignIn})
    : _auth = auth,
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
    return _auth.idTokenChanges().map((firebaseUser) {
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
  Future<AppUser> signInWithEmail({required String email, required String password, required bool register, String? displayName}) async {
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

      final credential = auth.GoogleAuthProvider.credential(accessToken: authClient.accessToken, idToken: authClient.idToken);

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
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  @override
  Future<void> deleteUserProfile(AppUser user) async {
    final groups = await _firestore.collection('groups').where('memberIds', arrayContains: user.id).get();
    for (final doc in groups.docs) {
      final group = ExpenseGroup.fromMap(doc.data());
      final remainingActive = group.activeMembers.where((entry) => entry.userId != user.id).toList();
      final ownerId = group.ownerId == user.id && remainingActive.isNotEmpty ? remainingActive.first.userId : group.ownerId;
      final adminIds = group.adminIds
          .where((entry) => entry != user.id)
          .where((entry) => remainingActive.any((member) => member.userId == entry))
          .toList();
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
        group
            .copyWith(
              ownerId: ownerId,
              adminIds: adminIds,
              members: updatedMembers,
              memberIds: group.memberIds.where((entry) => entry != user.id).toList(),
              updatedAt: DateTime.now(),
            )
            .toMap(),
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

  /// Modelos ya construidos, indexados por documento y version.
  ///
  /// Un grupo con doscientos gastos son varios miles de objetos al
  /// deserializarlo. Sin esta cache, tocar un solo gasto de un solo grupo
  /// obligaba a reconstruir **todos** los grupos del usuario, en el hilo de
  /// interfaz y en cada instantanea.
  final Map<String, _CachedGroup> _groupCache = <String, _CachedGroup>{};

  /// Ultima ficha de invitacion publicada por este dispositivo para cada grupo.
  /// Evita reescribir `invites` en cada instantanea cuando nada publico cambia.
  final Map<String, GroupInvitePreview> _publishedInvites = <String, GroupInvitePreview>{};

  ExpenseGroup _materializeGroup(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('El grupo ${doc.id} no tiene datos.');
    }

    // `updatedAt` cambia en cada escritura, asi que sirve de version del
    // documento sin tener que comparar el mapa entero.
    final version = data['updatedAt']?.toString() ?? '';
    final cached = _groupCache[doc.id];
    if (cached != null && cached.version == version) {
      return cached.group;
    }

    final group = ExpenseGroup.fromMap(data);
    _groupCache[doc.id] = _CachedGroup(version: version, group: group);
    unawaited(_syncInviteMirror(group));
    return group;
  }

  /// Mantiene al dia `invites/{codigo}`, la ficha publica del grupo (ADR-0009).
  ///
  /// Se llama desde el unico sitio por el que pasan todos los grupos, asi que no
  /// hay que acordarse de refrescarla en cada escritura. Como tambien se dispara
  /// la primera vez que un miembro ve un grupo, sirve ademas de migracion: los
  /// grupos que existian antes de que hubiera coleccion `invites` publican su
  /// ficha solos, sin script aparte.
  ///
  /// Si falla, se traga el error a proposito: que no se pueda republicar una
  /// ficha no puede impedirle a nadie usar la app. Lo unico que pasa es que una
  /// invitacion enseñe un nombre viejo hasta el siguiente intento.
  Future<void> _syncInviteMirror(ExpenseGroup group) async {
    if (group.inviteCode.isEmpty) {
      return;
    }

    final ficha = GroupInvitePreview.fromGroup(group);
    if (_publishedInvites[group.id]?.matches(group) ?? false) {
      return;
    }

    try {
      await _firestore.collection('invites').doc(group.inviteCode).set(ficha.toMap());
      _publishedInvites[group.id] = ficha;
    } catch (_) {
      // Se reintenta con la siguiente instantanea del grupo.
    }
  }

  @override
  Stream<List<ExpenseGroup>> watchGroups(String userId) {
    return _watchCurrentUserScoped(
      userId,
      emptyValue: const <ExpenseGroup>[],
      subscribe: () => _streamWithAuthRetry(
        () => _firestore.collection('groups').where('memberIds', arrayContains: userId).snapshots().map((snapshot) {
          final groups = snapshot.docs.map(_materializeGroup).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          // Se limpian de la cache los grupos que ya no vienen en la consulta:
          // el usuario se ha salido o lo han borrado.
          final visibleIds = snapshot.docs.map((doc) => doc.id).toSet();
          _groupCache.removeWhere((id, _) => !visibleIds.contains(id));

          return groups;
        }),
      ),
    );
  }

  @override
  Stream<ExpenseGroup?> watchGroup(String groupId) {
    return _streamWithAuthRetry(
      () => _firestore.collection('groups').doc(groupId).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) {
          _groupCache.remove(doc.id);
          return null;
        }
        return _materializeGroup(doc);
      }),
    );
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _watchCurrentUserScoped(
      userId,
      emptyValue: const <AppNotification>[],
      subscribe: () => _streamWithAuthRetry(
        () => _notificationsRef(userId).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
          return snapshot.docs.map((doc) => AppNotification.fromMap(doc.data())).toList();
        }),
      ),
    );
  }

  @override
  Future<GroupInvitePreview?> previewInvite(String rawInvite) {
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

    await _firestore.collection('groups').doc(id).set(group.toMap());
    return group;
  }

  @override
  Future<void> joinGroupByInvite({
    required AppUser user,
    required String rawInvite,
    required String joinPin,
    String? pendingMemberId,
  }) async {
    final ficha = await _resolveInvite(rawInvite);
    if (ficha == null) {
      throw StateError('No se encontró ningún grupo con esa invitación.');
    }
    if (ficha.isClosed) {
      throw StateError('El grupo está cerrado y no admite nuevas incorporaciones.');
    }

    final slot = pendingMemberId == null ? null : ficha.openSlots.firstWhereOrNull((entry) => entry.id == pendingMemberId);
    if (pendingMemberId != null && slot == null) {
      throw StateError('Ese hueco ya lo ha ocupado otra persona.');
    }
    if (slot == null && !ficha.allowAnonymousJoin) {
      throw StateError('El administrador debe indicar qué persona se está uniendo o activar el acceso libre por enlace.');
    }

    // Aqui esta lo que cambia respecto a la version anterior: NO se lee el
    // grupo. No se puede, y no hace falta (ADR-0009).
    //
    // - La lista de miembros se amplia con `arrayUnion`, que no necesita conocer
    //   la lista actual.
    // - El PIN lo verifican las reglas contra el valor real, comparandolo con
    //   `joinProof`. Antes se comparaba en el movil despues de leer el grupo,
    //   que era tanto como no comprobarlo.
    // - Reclamar el hueco de «Marta» ya no reescribe todos los gastos: se anota
    //   la equivalencia en `claimedSlots` y se resuelve al leer.
    final patch = <String, dynamic>{
      'memberIds': FieldValue.arrayUnion(<String>[user.id]),
      'members': FieldValue.arrayUnion(<Map<String, dynamic>>[
        GroupMember(userId: user.id, name: slot?.name ?? user.displayName, email: user.email, photoUrl: user.photoUrl).toMap(),
      ]),
      'joinProof': joinProofFor(joinPin: joinPin, userId: user.id),
      'updatedAt': DateTime.now().toIso8601String(),
      if (slot != null) 'claimedSlots.${slot.id}': user.id,
    };

    try {
      await _firestore.collection('groups').doc(ficha.groupId).update(patch);
    } on FirebaseException catch (error) {
      // Las reglas no distinguen por que han dicho que no, asi que el motivo mas
      // probable con diferencia es el PIN. Devolver «permiso denegado» a alguien
      // que se ha equivocado tecleando cuatro digitos no ayuda a nadie.
      if (error.code == 'permission-denied') {
        throw StateError('El PIN del grupo no es correcto.');
      }
      rethrow;
    }
  }

  @override
  Future<void> addExpense({required String groupId, required ExpenseRecord expense}) async {
    final docRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = ExpenseGroup.fromMap(snapshot.data()!);
      _ensureGroupAllowsExpense(current, expense);
      final updated = current.copyWith(expenses: [...current.expenses, expense], updatedAt: DateTime.now());
      transaction.update(docRef, _expensesPatch(updated));
    });
    final group = await _resolveGroup(groupId);
    if (group != null) {
      try {
        await _notifyExpenseEvent(group: group, expense: expense);
      } catch (_) {}
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
      transaction.update(docRef, _expensesPatch(updated));
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
      transaction.update(docRef, _expensesPatch(updated));
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
      final updated = current.copyWith(customCategories: categories, updatedAt: DateTime.now());
      transaction.update(docRef, <String, Object?>{
        'customCategories': updated.customCategories.map((entry) => entry.toMap()).toList(growable: false),
        'updatedAt': updated.updatedAt.toIso8601String(),
      });
    });
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
    final docRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = ExpenseGroup.fromMap(snapshot.data()!);
      _ensureGroupOpen(current);
      transaction.set(
        docRef,
        current
            .copyWith(
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
            )
            .toMap(),
      );
    });
  }

  @override
  Future<void> transferGroupOwnership({required String groupId, required String requesterId, required String newOwnerId}) async {
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
  Future<void> setGroupAdmins({required String groupId, required String requesterId, required List<String> adminIds}) async {
    final docRef = _firestore.collection('groups').doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = ExpenseGroup.fromMap(snapshot.data()!);
      if (current.ownerId != requesterId) {
        throw StateError('Solo la persona administradora principal puede cambiar otros administradores.');
      }
      final validAdminIds = adminIds
          .where((entry) => entry != current.ownerId)
          .where((entry) => current.activeMembers.any((member) => member.userId == entry))
          .toSet()
          .toList();
      transaction.set(docRef, current.copyWith(adminIds: validAdminIds, updatedAt: DateTime.now()).toMap());
    });
  }

  @override
  Future<void> leaveGroup({required String groupId, required String userId}) async {
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
        current
            .copyWith(
              adminIds: current.adminIds.where((entry) => entry != userId).toList(),
              memberIds: remainingIds,
              members: current.members.map((entry) {
                if (entry.userId != userId) {
                  return entry;
                }
                return entry.copyWith(isArchived: true, archivedAt: DateTime.now());
              }).toList(),
              updatedAt: DateTime.now(),
            )
            .toMap(),
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
      final now = DateTime.now();
      final updated = isClosed ? current.archived(at: now) : current.copyWith(isClosed: false, closedAt: null, updatedAt: now);
      transaction.set(docRef, updated.toMap());
    });
  }

  @override
  Future<void> deleteGroup({required String groupId, required String requesterId}) async {
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

      transaction.update(docRef, _expensesPatch(current.copyWith(expenses: updatedExpenses, updatedAt: DateTime.now())));
    });
  }

  @override
  Future<void> requestReimbursement({
    required String groupId,
    required String requesterId,
    required String targetUserId,
    required double amount,
  }) async {
    final group = await _resolveGroup(groupId);
    if (group == null) {
      throw StateError('Grupo no encontrado.');
    }
    final targetMember = group.visibleMembers.firstWhereOrNull((entry) => entry.userId == targetUserId);
    if (targetUserId.startsWith('pending:') || (targetMember?.isPending ?? false) || (targetMember?.isDeletedAccount ?? false)) {
      return;
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

    final edges = settlementEdges(group, activeAccountsOnly: false);
    final balances = memberBalances(group);
    final admin = group.members.firstWhereOrNull((entry) => entry.userId == requesterId);
    final recipientIds = edges
        .expand((edge) => [edge.fromUserId, edge.toUserId])
        .where((userId) => userId != requesterId && !userId.startsWith('pending:'))
        .toSet();
    final recipients = group.visibleMembers
        .where((entry) => recipientIds.contains(entry.userId) && !entry.isPending && !entry.isDeletedAccount)
        .toList();
    var sent = 0;

    await Future.wait(
      recipients.map((member) async {
        final balance = balances[member.userId] ?? 0;
        final amount = balance.abs();
        if (amount <= 0.009) {
          return;
        }
        sent += 1;
        final message = balance < 0
            ? '${admin?.name ?? 'La persona administradora'} te pide saldar ${amount.toStringAsFixed(2)} ${group.currency} en ${group.name}.'
            : '${admin?.name ?? 'La persona administradora'} te avisa de que tienes ${amount.toStringAsFixed(2)} ${group.currency} a favor en ${group.name}.';
        await _createNotification(
          AppNotification(
            id: _uuid.v4(),
            userId: member.userId,
            type: AppNotificationType.groupSettlementRequested,
            title: 'Liquidación del grupo',
            message: message,
            createdAt: DateTime.now(),
            groupId: group.id,
            fromUserId: requesterId,
            relatedUserId: member.userId,
            amount: amount,
          ),
        );
      }),
    );

    return sent;
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

  /// Campos que cambian al tocar la lista de gastos.
  ///
  /// Enviar solo esto en lugar del documento entero reduce mucho el trafico de
  /// escritura y, sobre todo, evita pisar los cambios que otro miembro haya
  /// hecho a los miembros o a los ajustes del grupo en el mismo instante.
  Map<String, Object?> _expensesPatch(ExpenseGroup group) {
    return <String, Object?>{
      'expenses': group.expenses.map((entry) => entry.toMap()).toList(growable: false),
      'updatedAt': group.updatedAt.toIso8601String(),
    };
  }

  @override
  Future<ExpenseGroup> restoreGroup({required AppUser owner, required ExpenseGroup group}) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final restoredMembers = <GroupMember>[
      GroupMember(userId: owner.id, name: owner.displayName, email: owner.email, photoUrl: owner.photoUrl),
      ...group.members.where((member) => member.userId != owner.id),
    ];

    final restored = group.copyWith(
      id: id,
      inviteCode: _uuid.v4().split('-').first.toUpperCase(),
      joinPin: generateGroupJoinPin(),
      ownerId: owner.id,
      adminIds: const <String>[],
      members: restoredMembers,
      memberIds: <String>[owner.id],
      updatedAt: now,
    );

    // Solo se declara miembro a quien importa: el resto de personas del grupo
    // original siguen figurando por su nombre, pero sin acceso, porque sus
    // cuentas no han aceptado nada. Se vuelven a unir con la invitacion.
    await _firestore.collection('groups').doc(id).set(restored.toMap());
    return restored;
  }

  @override
  Future<void> seedDemoData(AppUser user) async {}

  CollectionReference<Map<String, dynamic>> _notificationsRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('notifications');
  }

  Stream<T> _watchCurrentUserScoped<T>(String userId, {required T emptyValue, required Stream<T> Function() subscribe}) {
    return _auth.idTokenChanges().asyncExpand((firebaseUser) {
      if (firebaseUser == null || firebaseUser.uid != userId) {
        return Stream<T>.value(emptyValue);
      }
      return subscribe();
    });
  }

  Future<ExpenseGroup?> _resolveGroup(String groupId) async {
    final snapshot = await _firestore.collection('groups').doc(groupId).get();
    return snapshot.data() == null ? null : ExpenseGroup.fromMap(snapshot.data()!);
  }

  Stream<T> _streamWithAuthRetry<T>(Stream<T> Function() subscribe) {
    const maxPermissionDeniedRetries = 2;
    // El controlador se cierra en su propio `onCancel`, mas abajo; el analizador
    // no sigue esa ruta.
    // ignore: close_sinks
    late final StreamController<T> controller;
    StreamSubscription<T>? subscription;
    var permissionDeniedRetries = 0;

    Future<void> startListening() async {
      await subscription?.cancel();
      if (controller.isClosed) {
        return;
      }

      subscription = subscribe().listen(
        (event) {
          permissionDeniedRetries = 0;
          controller.add(event);
        },
        onError: (Object error, StackTrace stackTrace) async {
          final shouldRetry = _isPermissionDenied(error) && permissionDeniedRetries < maxPermissionDeniedRetries;
          if (shouldRetry) {
            permissionDeniedRetries += 1;
            final refreshed = await _refreshAuthSession();
            if (refreshed && !controller.isClosed) {
              await startListening();
              return;
            }
          }

          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
        cancelOnError: false,
      );
    }

    controller = StreamController<T>(
      onListen: () {
        unawaited(startListening());
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }

  bool _isPermissionDenied(Object error) {
    return error is FirebaseException && error.code == 'permission-denied';
  }

  Future<bool> _refreshAuthSession() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return false;
    }

    try {
      await currentUser.getIdToken(true);
      return true;
    } catch (_) {
      return false;
    }
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

  Future<void> _createNotification(AppNotification notification) {
    return _notificationsRef(notification.userId).doc(notification.id).set(notification.toMap());
  }

  Future<void> _notifyExpenseEvent({required ExpenseGroup group, required ExpenseRecord expense}) async {
    final recipients = group.activeMembers
        .where(
          (entry) => entry.userId != expense.payerId && !entry.isPending && !entry.isDeletedAccount && !entry.userId.startsWith('pending:'),
        )
        .toList();
    final payer = group.members.firstWhereOrNull((entry) => entry.userId == expense.payerId);
    final actorUserId = _auth.currentUser?.uid ?? expense.payerId;

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
              fromUserId: actorUserId,
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
            message:
                '${payer?.name ?? 'Una persona'} registró un reembolso de ${expense.items.fold<double>(0, (totalAmount, item) => totalAmount + item.amount).toStringAsFixed(2)} ${group.currency} en ${group.name}.',
            createdAt: DateTime.now(),
            groupId: group.id,
            expenseId: expense.id,
            fromUserId: actorUserId,
            relatedUserId: userId,
          ),
        ),
      ),
    );
  }

  /// Busca la ficha publica de una invitacion.
  ///
  /// Antes esto consultaba la coleccion `groups` por `inviteCode`, y para que
  /// funcionara las reglas dejaban leer cualquier grupo a cualquiera con cuenta
  /// (ADR-0009). Ahora lee `invites/{codigo}`, que solo tiene lo que se le puede
  /// enseñar a un desconocido.
  ///
  /// El codigo hay que conocerlo: `invites` no se puede enumerar.
  Future<GroupInvitePreview?> _resolveInvite(String rawInvite) async {
    final value = rawInvite.trim();
    if (value.isEmpty) {
      return null;
    }

    final reference = _parseInviteReference(value);
    final code = (reference?.token?.isNotEmpty ?? false) ? reference!.token!.toUpperCase() : value.toUpperCase();

    final snapshot = await _firestore.collection('invites').doc(code).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    final ficha = GroupInvitePreview.fromMap(code, data);

    // Un enlace lleva tambien el identificador del grupo. Si no cuadra con el
    // que dice la ficha, el enlace esta manipulado o caducado.
    if (reference != null && reference.groupId.isNotEmpty && ficha.groupId != reference.groupId) {
      return null;
    }

    return ficha.groupId.isEmpty ? null : ficha;
  }

  _InviteReference? _parseInviteReference(String rawInvite) {
    final uri = Uri.tryParse(rawInvite);

    if (uri != null && uri.queryParameters.containsKey('group')) {
      final groupId = uri.queryParameters['group'];
      if (groupId != null && groupId.isNotEmpty) {
        return _InviteReference(groupId: groupId, token: uri.queryParameters['token']?.trim());
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

  String _mapAuthException(auth.FirebaseAuthException error, {bool register = false, bool google = false}) {
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

/// Modelo cacheado de un grupo junto con la version del documento del que sale.
class _CachedGroup {
  const _CachedGroup({required this.version, required this.group});

  final String version;
  final ExpenseGroup group;
}
