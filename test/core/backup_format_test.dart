import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shardpay/core/backup_format.dart';
import 'package:shardpay/core/expense_math.dart';
import 'package:shardpay/models/app_models.dart';

void main() {
  group('BackupDocument', () {
    test('la ida y vuelta devuelve exactamente el mismo estado', () {
      // Este es el criterio de la Definition of Done: exportar, borrar e
      // importar tiene que dejar los datos como estaban, al centimo.
      final original = _payload();
      final encoded = BackupDocument.create(appVersion: '1.0.0', payload: original).encode();
      final restored = BackupDocument.decode(encoded).payload;

      expect(restored.groups.length, original.groups.length);
      expect(restored.preferences, original.preferences);

      final before = original.groups.single;
      final after = restored.groups.single;

      expect(after.id, before.id);
      expect(after.name, before.name);
      expect(after.currency, before.currency);
      expect(after.members.map((member) => member.userId), before.members.map((member) => member.userId));
      expect(after.pendingMembers.map((entry) => entry.id), before.pendingMembers.map((entry) => entry.id));
      expect(after.expenses.length, before.expenses.length);
      expect(totalGroupSpend(after), totalGroupSpend(before));
      expect(memberBalances(after), memberBalances(before));
      expect(after.createdAt, before.createdAt);
      expect(
        after.expenses.single.items.single.allocations.map((entry) => entry.percentage),
        before.expenses.single.items.single.allocations.map((entry) => entry.percentage),
      );
    });

    test('la cabecera lleva formato, esquema, version y fecha', () {
      final document = BackupDocument.create(
        appVersion: '1.2.3',
        payload: _payload(),
        deviceLabel: 'Pixel de pruebas',
        createdAt: DateTime.utc(2026, 8, 31, 10, 30),
      );

      final json = jsonDecode(document.encode()) as Map<String, dynamic>;

      expect(json['format'], backupFormatId);
      expect(json['schemaVersion'], backupSchemaVersion);
      expect(json['appVersion'], '1.2.3');
      expect(json['deviceLabel'], 'Pixel de pruebas');
      expect(json['createdAt'], '2026-08-31T10:30:00.000Z');
      expect(json['checksum'], isA<String>());
    });

    test('rechaza un fichero que no es JSON', () {
      expect(
        () => BackupDocument.decode('esto no es json'),
        throwsA(isA<BackupFormatException>().having((error) => error.error, 'error', BackupError.unreadable)),
      );
    });

    test('rechaza un JSON que no es una copia de ShardPay', () {
      expect(
        () => BackupDocument.decode('{"hola":"mundo"}'),
        throwsA(isA<BackupFormatException>().having((error) => error.error, 'error', BackupError.notAShardPayBackup)),
      );
    });

    test('rechaza una copia de una version futura', () {
      final encoded = BackupDocument.create(appVersion: '9.9.9', payload: _payload()).encode();
      final tampered = jsonDecode(encoded) as Map<String, dynamic>;
      tampered['schemaVersion'] = backupSchemaVersion + 1;

      expect(
        () => BackupDocument.decode(jsonEncode(tampered)),
        throwsA(isA<BackupFormatException>().having((error) => error.error, 'error', BackupError.schemaTooNew)),
      );
    });

    test('detecta un fichero manipulado por la suma de verificacion', () {
      final encoded = BackupDocument.create(appVersion: '1.0.0', payload: _payload()).encode();
      final tampered = jsonDecode(encoded) as Map<String, dynamic>;
      final payload = tampered['payload'] as Map<String, dynamic>;
      final groups = payload['groups'] as List<dynamic>;
      (groups.first as Map<String, dynamic>)['name'] = 'Grupo cambiado a mano';

      expect(
        () => BackupDocument.decode(jsonEncode(tampered)),
        throwsA(isA<BackupFormatException>().having((error) => error.error, 'error', BackupError.checksumMismatch)),
      );
    });

    test('rechaza una copia vacia', () {
      final empty = BackupDocument.create(
        appVersion: '1.0.0',
        payload: const BackupPayload(preferences: <String, Object?>{}, groups: <ExpenseGroup>[]),
      );

      expect(
        () => BackupDocument.decode(empty.encode()),
        throwsA(isA<BackupFormatException>().having((error) => error.error, 'error', BackupError.empty)),
      );
    });

    test('la suma de verificacion es estable y positiva', () {
      final first = checksumOf('ShardPay');
      expect(first, checksumOf('ShardPay'));
      expect(first, isNot(checksumOf('ShardPay ')));
      expect(first.length, 16);
      expect(first.startsWith('-'), isFalse);
    });
  });

  group('migratePayload', () {
    test('deja intacto el contenido de la version vigente', () {
      final payload = <String, Object?>{
        'groups': <Object?>[],
        'preferences': <String, Object?>{'a': 1},
      };
      expect(migratePayload(payload, from: backupSchemaVersion), same(payload));
    });
  });
}

BackupPayload _payload() {
  final createdAt = DateTime.utc(2026, 5, 4, 18, 45);

  return BackupPayload(
    preferences: const <String, Object?>{
      'app.theme': 'aurora',
      'app.language': 'gl',
      'notifications.expense': false,
      'donation.dismissedForever': true,
    },
    groups: <ExpenseGroup>[
      ExpenseGroup(
        id: 'g1',
        name: 'Viaje a Ourense',
        iconKey: 'groups',
        currency: 'EUR',
        ownerId: 'u1',
        adminIds: const <String>['u2'],
        inviteCode: 'OURENSE',
        joinPin: '4321',
        memberIds: const <String>['u1', 'u2'],
        members: const <GroupMember>[
          GroupMember(userId: 'u1', name: 'Brais', email: 'brais@example.com'),
          GroupMember(userId: 'u2', name: 'Ana', email: 'ana@example.com'),
        ],
        pendingMembers: const <PendingGroupMember>[PendingGroupMember(id: 'p1', name: 'Invitado')],
        allowAnonymousJoin: false,
        customCategories: const <ExpenseCategory>[ExpenseCategory(id: 'termas', name: 'Termas', iconKey: 'spa', colorHex: '0xFF0077B6')],
        expenses: <ExpenseRecord>[
          ExpenseRecord(
            id: 'e1',
            title: 'Cena',
            payerId: 'u1',
            createdAt: createdAt,
            note: 'Leido del ticket',
            items: const <ExpenseItem>[
              ExpenseItem(
                id: 'i1',
                name: 'Menu degustacion',
                amount: 64.30,
                categoryId: 'food',
                allocations: <SplitAllocation>[
                  SplitAllocation(userId: 'u1', percentage: 33.33),
                  SplitAllocation(userId: 'u2', percentage: 33.33),
                  SplitAllocation(userId: 'pending:p1', percentage: 33.34),
                ],
              ),
            ],
          ),
        ],
        createdAt: createdAt,
        updatedAt: createdAt,
        isClosed: false,
      ),
    ],
  );
}
