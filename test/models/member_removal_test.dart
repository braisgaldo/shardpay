import 'package:flutter_test/flutter_test.dart';
import 'package:shardpay/models/app_models.dart';
import 'package:shardpay/repositories/mock/mock_app_repository.dart';

/// Dos cosas que la politica de privacidad promete y el codigo tiene que
/// cumplir, mas la expulsion de un miembro por parte de quien administra.
///
/// Se prueban juntas porque comparten la misma frontera: quitar a alguien de un
/// grupo **conserva** su nombre, y borrarse la cuenta lo **elimina**. Confundir
/// las dos es exactamente el fallo que estas pruebas existen para impedir.
void main() {
  group('anonymized', () {
    const miembro = GroupMember(
      userId: 'u1',
      name: 'Marta Ferreiro',
      email: 'marta@example.com',
      photoUrl: 'https://example.com/marta.jpg',
    );

    test('borra el nombre, el correo y la foto, y conserva el identificador', () {
      final anonimo = miembro.anonymized(at: DateTime(2026, 9, 2));

      expect(anonimo.userId, 'u1', reason: 'los gastos apuntan al identificador: quitarlo rompe los saldos');
      expect(anonimo.name, isEmpty);
      expect(anonimo.email, isEmpty);
      expect(anonimo.photoUrl, isNull);
      expect(anonimo.isArchived, isTrue);
      expect(anonimo.isDeletedAccount, isTrue);
      expect(anonimo.archivedAt, DateTime(2026, 9, 2));
    });

    test('lo que se guarda no lleva nada personal', () {
      final guardado = miembro.anonymized().toMap();

      expect(guardado.values.whereType<String>(), isNot(contains('Marta Ferreiro')));
      expect(guardado['email'], isEmpty);
      expect(guardado['photoUrl'], isNull);
    });

    test('al releerlo cae al nombre de respaldo y no se queda sin inicial', () {
      // La lista de personas del grupo pinta `name.substring(0, 1)`. Con el
      // nombre en blanco eso reventaria, asi que un nombre vacio tiene que caer
      // al mismo respaldo que un nombre ausente.
      final releido = GroupMember.fromMap(miembro.anonymized().toMap());

      expect(releido.name, isNotEmpty);
      expect(releido.name.substring(0, 1), isNotEmpty);
      expect(releido.name, isNot('Marta Ferreiro'));
      expect(releido.isDeletedAccount, isTrue);
    });
  });

  group('removeGroupMember', () {
    late MockAppRepository repositorio;
    late AppUser propietaria;
    late ExpenseGroup grupo;

    setUp(() async {
      repositorio = MockAppRepository();
      propietaria = await repositorio.signInWithEmail(email: 'ana@example.com', password: 'secreta', register: true);
      grupo = await repositorio.createGroup(
        owner: propietaria,
        name: 'Cena del viernes',
        iconKey: 'groups',
        currency: 'EUR',
        pendingMembers: const [PendingGroupMember(id: 'hueco-1', name: 'Marta')],
      );
    });

    Future<AppUser> entraMarta() async {
      final marta = AppUser(id: 'marta', email: 'marta@example.com', displayName: 'Marta', createdAt: DateTime(2026, 9, 1));
      await repositorio.joinGroupByInvite(
        user: marta,
        rawInvite: grupo.inviteCode,
        joinPin: grupo.joinPin,
        pendingMemberId: 'hueco-1',
      );
      return marta;
    }

    Future<ExpenseGroup> estadoActual() async => (await repositorio.watchGroup(grupo.id).first)!;

    test('quien administra puede quitar a alguien, y su participacion queda archivada', () async {
      final marta = await entraMarta();

      await repositorio.removeGroupMember(groupId: grupo.id, requesterId: propietaria.id, userId: marta.id);

      final despues = await estadoActual();
      expect(despues.memberIds, isNot(contains(marta.id)));
      expect(despues.adminIds, isNot(contains(marta.id)));

      final archivada = despues.members.firstWhere((entry) => entry.userId == marta.id);
      expect(archivada.isArchived, isTrue);
      expect(archivada.archivedAt, isNotNull);

      // Quitar a alguien no es borrarle la cuenta: su nombre se queda, porque el
      // historico de saldos del resto del grupo se lee con nombres.
      expect(archivada.isDeletedAccount, isFalse);
      expect(archivada.name, 'Marta');
    });

    test('deja de ver el grupo', () async {
      final marta = await entraMarta();
      expect(await repositorio.watchGroups(marta.id).first, isNotEmpty);

      await repositorio.removeGroupMember(groupId: grupo.id, requesterId: propietaria.id, userId: marta.id);

      expect(await repositorio.watchGroups(marta.id).first, isEmpty);
    });

    test('quien no administra no puede quitar a nadie', () async {
      final marta = await entraMarta();

      await expectLater(
        repositorio.removeGroupMember(groupId: grupo.id, requesterId: marta.id, userId: propietaria.id),
        throwsStateError,
      );
      expect((await estadoActual()).memberIds, contains(propietaria.id));
    });

    test('ni siquiera otra persona que administre puede quitar a la propietaria', () async {
      final marta = await entraMarta();
      await repositorio.setGroupAdmins(groupId: grupo.id, requesterId: propietaria.id, adminIds: [marta.id]);

      await expectLater(
        repositorio.removeGroupMember(groupId: grupo.id, requesterId: marta.id, userId: propietaria.id),
        throwsStateError,
      );
      expect((await estadoActual()).memberIds, contains(propietaria.id));
    });

    test('quitarse a uno mismo redirige a «Salir del grupo»', () async {
      await entraMarta();

      await expectLater(
        repositorio.removeGroupMember(groupId: grupo.id, requesterId: propietaria.id, userId: propietaria.id),
        throwsStateError,
      );
      expect((await estadoActual()).memberIds, contains(propietaria.id));
    });

    test('quitar a quien ya no esta no cambia nada', () async {
      final antes = await estadoActual();

      await repositorio.removeGroupMember(groupId: grupo.id, requesterId: propietaria.id, userId: 'nadie');

      expect((await estadoActual()).memberIds, antes.memberIds);
    });
  });
}
