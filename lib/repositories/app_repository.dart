import '../models/app_models.dart';

abstract class AppRepository {
  bool get isFirebaseBacked;

  Stream<AppUser?> authStateChanges();
  Future<AppUser> signInWithEmail({required String email, required String password, required bool register, String? displayName});
  Future<AppUser> signInWithGoogle();
  Future<void> signOut();
  Future<void> deleteUserProfile(AppUser user);
  Stream<List<ExpenseGroup>> watchGroups(String userId);
  Stream<ExpenseGroup?> watchGroup(String groupId);
  Stream<List<AppNotification>> watchNotifications(String userId);

  /// Ficha publica de una invitacion: lo unico que se puede saber de un grupo
  /// sin ser miembro. Vease ADR-0009.
  Future<GroupInvitePreview?> previewInvite(String rawInvite);
  Future<ExpenseGroup> createGroup({
    required AppUser owner,
    required String name,
    required String iconKey,
    required String currency,
    required List<PendingGroupMember> pendingMembers,
  });
  Future<void> joinGroupByInvite({required AppUser user, required String rawInvite, required String joinPin, String? pendingMemberId});
  Future<void> addExpense({required String groupId, required ExpenseRecord expense});
  Future<void> updateExpense({required String groupId, required ExpenseRecord expense});
  Future<void> deleteExpense({required String groupId, required String expenseId});
  Future<void> upsertCategory({required String groupId, required ExpenseCategory category});
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
  });
  Future<void> transferGroupOwnership({required String groupId, required String requesterId, required String newOwnerId});
  Future<void> setGroupAdmins({required String groupId, required String requesterId, required List<String> adminIds});
  Future<void> setGroupClosed({required String groupId, required String requesterId, required bool isClosed});
  Future<void> leaveGroup({required String groupId, required String userId});

  /// Expulsa a alguien del grupo. Solo quien administra el grupo puede hacerlo.
  ///
  /// No es lo mismo que borrar una cuenta: la participacion queda archivada con
  /// su nombre, porque el historico de saldos del resto del grupo la necesita.
  Future<void> removeGroupMember({required String groupId, required String requesterId, required String userId});
  Future<void> deleteGroup({required String groupId, required String requesterId});
  Future<void> updateItemAllocations({
    required String groupId,
    required String expenseId,
    required String itemId,
    required List<SplitAllocation> allocations,
  });
  Future<void> requestReimbursement({
    required String groupId,
    required String requesterId,
    required String targetUserId,
    required double amount,
  });
  Future<int> requestGroupSettlementNotifications({required String groupId, required String requesterId});
  Future<void> markNotificationRead({required String userId, required String notificationId});

  /// Vuelve a crear un grupo a partir de una copia de seguridad.
  ///
  /// El grupo se restaura como **grupo nuevo** del usuario que importa: se le
  /// asigna un identificador y un codigo de invitacion nuevos y pasa a ser su
  /// propietario. Restaurar sobre el identificador original machacaria los
  /// cambios que otros miembros hayan hecho mientras tanto, y esos datos no son
  /// solo de quien importa.
  Future<ExpenseGroup> restoreGroup({required AppUser owner, required ExpenseGroup group});

  Future<void> seedDemoData(AppUser user);
}
