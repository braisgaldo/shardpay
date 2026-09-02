import 'package:flutter_test/flutter_test.dart';
import 'package:shardpay/core/join_proof.dart';
import 'package:shardpay/models/app_models.dart';

/// El formato de la prueba del PIN esta pactado con `firestore.rules`, que la
/// recalcula del lado del servidor. Si estas dos implementaciones se separan,
/// nadie puede entrar en ningun grupo: el sintoma es un «permiso denegado»
/// generico que no dice nada.
///
/// Los valores esperados de aqui son los mismos que usa
/// `firestore-tests/rules.test.js`, que los comprueba contra el emulador de
/// verdad. Esta suite es la mitad barata: corre sin Java y sin emulador.
void main() {
  group('prueba del PIN', () {
    test('coincide con el valor que verifican las reglas', () {
      // sha256("4821:uid-bea") en hex mayuscula. Comprobado contra el emulador.
      expect(joinProofFor(joinPin: '4821', userId: 'uid-bea'), 'B513C71986840F733465CBF4B4DDA882ADCB21C9EF867C98ACFE56E4D65E8151');
    });

    test('el formato no depende del uid que toque', () {
      // Esta es la prueba que faltaba, y la que habria pillado el fallo.
      //
      // Antes esto era base64 y no coincidia con las reglas cuando el hash
      // llevaba `+` o `/`, o sea tres veces de cada cuatro. Se colo porque el
      // unico valor fijado era el de `uid-bea`, que da la casualidad de no
      // llevarlos. Hex solo admite 0-9 y A-F: si esto pasa para cien uids, pasa
      // para todos.
      final formato = RegExp(r'^[0-9A-F]{64}$');
      for (var i = 0; i < 100; i += 1) {
        final prueba = joinProofFor(joinPin: '4821', userId: 'uid-barrido-$i');
        expect(formato.hasMatch(prueba), isTrue, reason: 'formato inesperado para uid-barrido-$i: $prueba');
      }
    });

    test('cambia con el usuario', () {
      // Si no dependiera del uid, bastaria con copiar la prueba de otro.
      expect(joinProofFor(joinPin: '4821', userId: 'uid-bea'), isNot(joinProofFor(joinPin: '4821', userId: 'uid-chus')));
    });

    test('cambia con el PIN', () {
      expect(joinProofFor(joinPin: '4821', userId: 'uid-bea'), isNot(joinProofFor(joinPin: '0000', userId: 'uid-bea')));
    });

    test('ignora los espacios de alrededor', () {
      expect(joinProofFor(joinPin: ' 4821 ', userId: 'uid-bea'), joinProofFor(joinPin: '4821', userId: 'uid-bea'));
    });
  });

  group('ficha publica de la invitacion', () {
    ExpenseGroup grupo() => ExpenseGroup(
      id: 'grupo-1',
      name: 'Roadtrip Costa',
      iconKey: 'plane',
      currency: 'EUR',
      ownerId: 'uid-ana',
      adminIds: const <String>[],
      inviteCode: 'COSTA26',
      joinPin: '4821',
      memberIds: const <String>['uid-ana'],
      members: const <GroupMember>[GroupMember(userId: 'uid-ana', name: 'Ana', email: 'ana@ejemplo.com')],
      pendingMembers: const <PendingGroupMember>[
        PendingGroupMember(id: 'slot-marta', name: 'Marta'),
        PendingGroupMember(id: 'slot-leo', name: 'Leo'),
      ],
      allowAnonymousJoin: false,
      customCategories: const <ExpenseCategory>[],
      expenses: <ExpenseRecord>[
        ExpenseRecord(
          id: 'gasto-1',
          title: 'Cena',
          payerId: 'uid-ana',
          createdAt: DateTime(2026, 7, 18),
          items: const <ExpenseItem>[ExpenseItem(id: 'l1', name: 'Cena', amount: 84, categoryId: 'food', allocations: <SplitAllocation>[])],
        ),
      ],
      createdAt: DateTime(2026, 7, 17),
      updatedAt: DateTime(2026, 7, 18),
      isClosed: false,
    );

    test('no publica nada que no se le enseñaria a un desconocido', () {
      // Esta es la prueba que justifica que exista la clase. Un campo de mas
      // aqui es una fuga de datos a cualquiera que tenga un codigo.
      final publicada = GroupInvitePreview.fromGroup(grupo()).toMap();
      final serializado = publicada.toString();

      for (final prohibido in <String>['joinPin', 'expenses', 'members', 'memberIds', 'ownerId', 'adminIds']) {
        expect(publicada.containsKey(prohibido), isFalse, reason: 'la ficha no puede llevar $prohibido');
      }
      expect(serializado, isNot(contains('4821')), reason: 'se ha colado el PIN');
      expect(serializado, isNot(contains('ana@ejemplo.com')), reason: 'se ha colado un correo');
      expect(serializado, isNot(contains('uid-ana')), reason: 'se ha colado un identificador de usuario');
      expect(serializado, isNot(contains('Cena')), reason: 'se ha colado un gasto');
    });

    test('sus claves son exactamente las que aceptan las reglas', () {
      // `firestore.rules` rechaza cualquier clave fuera de esta lista, asi que
      // una clave nueva aqui sin tocar las reglas rompe la escritura de la ficha.
      final publicada = GroupInvitePreview.fromGroup(grupo()).toMap();
      expect(publicada.keys.toSet(), GroupInvitePreview.publicKeys.toSet());
    });

    test('la ida y vuelta conserva lo que se enseña', () {
      final original = GroupInvitePreview.fromGroup(grupo());
      final recuperada = GroupInvitePreview.fromMap('COSTA26', original.toMap());

      expect(recuperada.groupId, original.groupId);
      expect(recuperada.groupName, 'Roadtrip Costa');
      expect(recuperada.memberCount, 1);
      expect(recuperada.openSlots.map((slot) => slot.name), <String>['Marta', 'Leo']);
      expect(recuperada.allowAnonymousJoin, isFalse);
      expect(recuperada.matches(grupo()), isTrue);
    });

    test('un hueco ya reclamado deja de ofrecerse', () {
      // Quien reclama el hueco entra en el grupo en la misma escritura, asi que
      // cuando alguien lee la ficha el reclamo ya cuenta.
      final base = grupo();
      final conReclamo = base.copyWith(
        memberIds: <String>[...base.memberIds, 'uid-bea'],
        members: <GroupMember>[
          ...base.members,
          const GroupMember(userId: 'uid-bea', name: 'Bea', email: 'bea@ejemplo.com'),
        ],
        claimedSlots: const <String, String>{'slot-marta': 'uid-bea'},
      );
      final ficha = GroupInvitePreview.fromGroup(conReclamo);

      expect(ficha.openSlots.map((slot) => slot.id), <String>['slot-leo']);
      expect(ficha.memberCount, 2);
    });

    test('un reclamo que apunta a alguien que no esta en el grupo no oculta el hueco', () {
      // Si un reclamo colgado escondiera el hueco, la parte del gasto que le
      // tocaba se quedaria sin nadie a quien cargarsela.
      final conReclamoColgado = grupo().copyWith(claimedSlots: const <String, String>{'slot-marta': 'uid-fantasma'});
      final ficha = GroupInvitePreview.fromGroup(conReclamoColgado);

      expect(ficha.openSlots.map((slot) => slot.id), <String>['slot-marta', 'slot-leo']);
    });

    test('detecta que la ficha publicada se ha quedado vieja', () {
      final antigua = GroupInvitePreview.fromGroup(grupo());
      final renombrado = grupo().copyWith(name: 'Roadtrip Costa 2026');

      expect(antigua.matches(renombrado), isFalse);
    });
  });
}
