// Pruebas de las reglas de seguridad de Firestore contra el emulador.
//
// Existen por ADR-0009: las reglas anteriores dejaban que cualquier usuario
// autenticado leyera cualquier grupo, y como el documento de un grupo lleva
// dentro todos sus gastos, eso era el historial completo de todo el mundo. Un
// fallo de este tipo no se ve leyendo el fichero por encima: hay que ejecutarlo.
//
//   npm install
//   npm test          (arranca el emulador y ejecuta esto)
//
// El emulador arranca sin reglas: las sube esta suite, leyendo el
// firestore.rules de verdad del repositorio. Asi no hay dos copias.
//
// Hace falta Java para el emulador de Firestore.

import { strict as assert } from 'node:assert';
import { createHash } from 'node:crypto';
import { after, before, describe, it } from 'node:test';
import { readFileSync } from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where, deleteField } from 'firebase/firestore';

const PROJECT_ID = 'shardpay-rules';
const EMULATOR_PORT = Number(process.env.FIRESTORE_EMULATOR_PORT ?? 8080);
// En CI y en local desde el repo, el fichero esta un nivel por encima. La
// variable permite ejecutar la suite desde otro directorio (por ejemplo, con
// node_modules instalado fuera del arbol para esquivar el limite de longitud de
// rutas de Windows).
const RULES = process.env.SHARDPAY_RULES ?? new URL('../firestore.rules', import.meta.url);

const ANA = 'uid-ana';
const BEA = 'uid-bea';
const CHUS = 'uid-chus';

const INVITE_CODE = 'COSTA26';
const JOIN_PIN = '4821';
const GROUP_ID = 'grupo-roadtrip';

/// La misma prueba que calcula el cliente: sha256("<pin>:<uid>") en base64.
function joinProof(pin, uid) {
  return createHash('sha256').update(`${pin}:${uid}`).digest('base64');
}

function grupoBase(overrides = {}) {
  return {
    id: GROUP_ID,
    name: 'Roadtrip Costa',
    iconKey: 'plane',
    currency: 'EUR',
    ownerId: ANA,
    adminIds: [],
    inviteCode: INVITE_CODE,
    joinPin: JOIN_PIN,
    memberIds: [ANA],
    members: [{ userId: ANA, name: 'Ana', email: 'ana@ejemplo.com' }],
    pendingMembers: [{ id: 'slot-marta', name: 'Marta' }],
    allowAnonymousJoin: false,
    customCategories: [],
    expenses: [{ id: 'gasto-1', title: 'Cena', payerId: ANA, items: [] }],
    createdAt: '2026-07-17T10:00:00.000',
    updatedAt: '2026-07-17T10:00:00.000',
    isClosed: false,
    ...overrides,
  };
}

function fichaInvitacion(overrides = {}) {
  return {
    groupId: GROUP_ID,
    groupName: 'Roadtrip Costa',
    iconKey: 'plane',
    currency: 'EUR',
    memberCount: 1,
    pendingMembers: [{ id: 'slot-marta', name: 'Marta' }],
    isClosed: false,
    allowAnonymousJoin: false,
    updatedAt: '2026-07-17T10:00:00.000',
    ...overrides,
  };
}

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES, 'utf8'),
      host: '127.0.0.1',
      port: EMULATOR_PORT,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

async function sembrar(extra = {}) {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'groups', GROUP_ID), grupoBase(extra.group));
    await setDoc(doc(db, 'invites', INVITE_CODE), fichaInvitacion(extra.invite));
  });
}

const como = (uid) => testEnv.authenticatedContext(uid).firestore();
const sinCuenta = () => testEnv.unauthenticatedContext().firestore();

describe('grupos: solo los miembros', () => {
  before(sembrar);

  it('un miembro puede leer su grupo', async () => {
    await assertSucceeds(getDoc(doc(como(ANA), 'groups', GROUP_ID)));
  });

  it('un usuario autenticado que NO es miembro no puede leerlo', async () => {
    // Este es exactamente el agujero de ADR-0009.
    await assertFails(getDoc(doc(como(BEA), 'groups', GROUP_ID)));
  });

  it('sin cuenta tampoco', async () => {
    await assertFails(getDoc(doc(sinCuenta(), 'groups', GROUP_ID)));
  });

  it('no se puede barrer la coleccion entera', async () => {
    await assertFails(getDocs(collection(como(BEA), 'groups')));
  });

  it('ni consultando por codigo de invitacion', async () => {
    // La consulta que hacia la app antes de existir `invites`.
    await assertFails(
      getDocs(query(collection(como(BEA), 'groups'), where('inviteCode', '==', INVITE_CODE))),
    );
  });

  it('un miembro si puede listar los grupos en los que esta', async () => {
    await assertSucceeds(
      getDocs(query(collection(como(ANA), 'groups'), where('memberIds', 'array-contains', ANA))),
    );
  });

  it('un extraño no puede escribir en el grupo', async () => {
    await assertFails(updateDoc(doc(como(BEA), 'groups', GROUP_ID), { name: 'Secuestrado' }));
  });
});

describe('invitaciones: ficha publica, sin datos del grupo', () => {
  before(sembrar);

  it('cualquiera con cuenta puede leer la ficha', async () => {
    const ficha = await assertSucceeds(getDoc(doc(como(BEA), 'invites', INVITE_CODE)));
    assert.equal(ficha.data().groupName, 'Roadtrip Costa');
  });

  it('la ficha no lleva PIN, ni gastos, ni correos', async () => {
    const ficha = await assertSucceeds(getDoc(doc(como(BEA), 'invites', INVITE_CODE)));
    const claves = Object.keys(ficha.data());
    for (const prohibida of ['joinPin', 'expenses', 'members', 'memberIds', 'ownerId', 'adminIds']) {
      assert.ok(!claves.includes(prohibida), `la ficha no debe llevar ${prohibida}`);
    }
  });

  it('sin cuenta no se puede leer', async () => {
    await assertFails(getDoc(doc(sinCuenta(), 'invites', INVITE_CODE)));
  });

  it('no se pueden enumerar las invitaciones', async () => {
    // Si esto se pudiera, el codigo dejaria de ser un secreto.
    await assertFails(getDocs(collection(como(BEA), 'invites')));
  });

  it('un miembro del grupo puede mantener la ficha al dia', async () => {
    await assertSucceeds(
      setDoc(doc(como(ANA), 'invites', INVITE_CODE), fichaInvitacion({ groupName: 'Roadtrip Costa 2' })),
    );
  });

  it('quien no es miembro no puede tocarla', async () => {
    await assertFails(
      setDoc(doc(como(BEA), 'invites', INVITE_CODE), fichaInvitacion({ groupName: 'Mio ahora' })),
    );
  });

  it('un miembro no puede colar campos privados en la ficha', async () => {
    await assertFails(
      setDoc(doc(como(ANA), 'invites', INVITE_CODE), fichaInvitacion({ joinPin: JOIN_PIN })),
    );
    await assertFails(
      setDoc(doc(como(ANA), 'invites', INVITE_CODE), fichaInvitacion({ expenses: [{ id: 'x' }] })),
    );
  });

  it('no se puede publicar una ficha bajo un codigo que no es el del grupo', async () => {
    await assertFails(setDoc(doc(como(ANA), 'invites', 'OTROCODIGO'), fichaInvitacion()));
  });
});

describe('unirse por invitacion', () => {
  const entrada = (uid, extra = {}) => ({
    memberIds: [ANA, uid],
    members: [
      { userId: ANA, name: 'Ana', email: 'ana@ejemplo.com' },
      { userId: uid, name: 'Bea', email: 'bea@ejemplo.com' },
    ],
    joinProof: joinProof(JOIN_PIN, uid),
    updatedAt: '2026-07-18T10:00:00.000',
    ...extra,
  });

  it('con el PIN correcto se entra', async () => {
    await sembrar();
    await assertSucceeds(updateDoc(doc(como(BEA), 'groups', GROUP_ID), entrada(BEA)));
  });

  it('con el PIN equivocado no', async () => {
    await sembrar();
    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), {
        ...entrada(BEA),
        joinProof: joinProof('0000', BEA),
      }),
    );
  });

  it('sin prueba del PIN tampoco', async () => {
    await sembrar();
    const sinPrueba = entrada(BEA);
    delete sinPrueba.joinProof;
    await assertFails(updateDoc(doc(como(BEA), 'groups', GROUP_ID), sinPrueba));
  });

  it('la prueba de otro usuario no vale', async () => {
    // Si el hash no incluyera el uid, bastaria con copiar la prueba de alguien.
    await sembrar();
    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), {
        ...entrada(BEA),
        joinProof: joinProof(JOIN_PIN, CHUS),
      }),
    );
  });

  it('al entrar no se pueden tocar los gastos', async () => {
    // El agujero de la regla anterior: `expenses` estaba en la lista de campos
    // que la operacion de entrada podia modificar.
    await sembrar();
    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), { ...entrada(BEA), expenses: [] }),
    );
  });

  it('ni el PIN ni el codigo de invitacion', async () => {
    await sembrar();
    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), { ...entrada(BEA), joinPin: '0000' }),
    );
    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), { ...entrada(BEA), inviteCode: 'OTRO' }),
    );
  });

  it('no se puede entrar metiendo a dos personas de golpe', async () => {
    await sembrar();
    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), {
        ...entrada(BEA),
        memberIds: [ANA, BEA, CHUS],
        members: [
          { userId: ANA, name: 'Ana', email: '' },
          { userId: BEA, name: 'Bea', email: '' },
          { userId: CHUS, name: 'Chus', email: '' },
        ],
      }),
    );
  });

  it('no se puede entrar en un grupo cerrado', async () => {
    await sembrar({ group: { isClosed: true } });
    await assertFails(updateDoc(doc(como(BEA), 'groups', GROUP_ID), entrada(BEA)));
  });

  it('se puede reclamar un hueco reservado', async () => {
    await sembrar();
    await assertSucceeds(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), {
        ...entrada(BEA),
        claimedSlots: { 'slot-marta': BEA },
      }),
    );
  });

  it('no se puede reclamar un hueco para otra persona', async () => {
    await sembrar();
    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), {
        ...entrada(BEA),
        claimedSlots: { 'slot-marta': CHUS },
      }),
    );
  });

  it('no se pueden reclamar dos huecos de una vez', async () => {
    await sembrar({ group: { pendingMembers: [{ id: 'slot-marta', name: 'Marta' }, { id: 'slot-leo', name: 'Leo' }] } });
    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), {
        ...entrada(BEA),
        claimedSlots: { 'slot-marta': BEA, 'slot-leo': BEA },
      }),
    );
  });

  it('no se puede robar un hueco ya reclamado', async () => {
    await sembrar({ group: { claimedSlots: { 'slot-marta': CHUS } } });
    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), {
        ...entrada(BEA),
        claimedSlots: { 'slot-marta': BEA },
      }),
    );
  });

  it('quien entra no puede darse permisos de administrador', async () => {
    // La lista de campos que la entrada puede tocar es lo unico que impide que
    // unirse a un grupo y apoderarse de el sean la misma operacion.
    await sembrar();
    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), { ...entrada(BEA), adminIds: [BEA] }),
    );
    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), { ...entrada(BEA), ownerId: BEA }),
    );
  });

  it('quien entra no puede cerrar el grupo ni renombrarlo', async () => {
    await sembrar();
    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), { ...entrada(BEA), isClosed: true }),
    );
    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), { ...entrada(BEA), name: 'Mio' }),
    );
  });
});

describe('un miembro sigue pudiendo trabajar', () => {
  it('puede añadir un gasto', async () => {
    await sembrar();
    await assertSucceeds(
      updateDoc(doc(como(ANA), 'groups', GROUP_ID), {
        expenses: [{ id: 'gasto-2', title: 'Gasolina', payerId: ANA, items: [] }],
        updatedAt: '2026-07-18T12:00:00.000',
      }),
    );
  });

  it('puede renombrar el grupo y cerrarlo', async () => {
    await sembrar();
    await assertSucceeds(
      updateDoc(doc(como(ANA), 'groups', GROUP_ID), { name: 'Roadtrip Costa 2026', isClosed: true }),
    );
  });

  it('puede salirse del grupo', async () => {
    // «Salir del grupo» y «Eliminar mi perfil» quitan al usuario de memberIds.
    // La rama normal de miembro exige seguir dentro despues de escribir, asi que
    // sin una regla propia estas dos funciones fallaban contra Firestore.
    await sembrar({ group: { memberIds: [ANA, BEA], members: [
      { userId: ANA, name: 'Ana', email: 'ana@ejemplo.com' },
      { userId: BEA, name: 'Bea', email: 'bea@ejemplo.com' },
    ] } });

    await assertSucceeds(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), {
        memberIds: [ANA],
        members: [
          { userId: ANA, name: 'Ana', email: 'ana@ejemplo.com' },
          { userId: BEA, name: 'Bea', email: 'bea@ejemplo.com', isArchived: true },
        ],
        updatedAt: '2026-07-19T10:00:00.000',
      }),
    );
  });

  it('al salirse no puede echar a nadie mas', async () => {
    await sembrar({ group: { memberIds: [ANA, BEA, CHUS], members: [
      { userId: ANA, name: 'Ana', email: '' },
      { userId: BEA, name: 'Bea', email: '' },
      { userId: CHUS, name: 'Chus', email: '' },
    ] } });

    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), {
        memberIds: [ANA],
        members: [{ userId: ANA, name: 'Ana', email: '' }],
        updatedAt: '2026-07-19T10:00:00.000',
      }),
    );
  });

  it('al salirse no puede llevarse por delante los gastos', async () => {
    await sembrar({ group: { memberIds: [ANA, BEA], members: [
      { userId: ANA, name: 'Ana', email: '' },
      { userId: BEA, name: 'Bea', email: '' },
    ] } });

    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), {
        memberIds: [ANA],
        members: [{ userId: ANA, name: 'Ana', email: '' }],
        expenses: [],
        updatedAt: '2026-07-19T10:00:00.000',
      }),
    );
  });

  it('puede salirse de un grupo en el que alguien entro por invitacion', async () => {
    // `leaveGroup` y `deleteUserProfile` escriben el documento ENTERO con
    // `set()`, y `ExpenseGroup.toMap()` no incluye `joinProof`, que es un campo
    // que deja la operacion de entrar. O sea que la escritura de salida **borra**
    // ese campo, y eso cuenta como clave afectada.
    await sembrar({ group: {
      memberIds: [ANA, BEA],
      members: [
        { userId: ANA, name: 'Ana', email: '' },
        { userId: BEA, name: 'Bea', email: '' },
      ],
      joinProof: joinProof(JOIN_PIN, BEA),
    } });

    await assertSucceeds(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), {
        memberIds: [ANA],
        members: [{ userId: ANA, name: 'Ana', email: '' }],
        joinProof: deleteField(),
        updatedAt: '2026-07-19T10:00:00.000',
      }),
    );
  });

  it('un extraño no puede echar a un miembro', async () => {
    await sembrar();
    await assertFails(
      updateDoc(doc(como(BEA), 'groups', GROUP_ID), { memberIds: [], members: [] }),
    );
  });
});

describe('usuarios y avisos', () => {
  before(sembrar);

  it('cada uno lee lo suyo y nada mas', async () => {
    await assertSucceeds(getDoc(doc(como(ANA), 'users', ANA)));
    await assertFails(getDoc(doc(como(BEA), 'users', ANA)));
  });

  it('no se puede avisar a alguien de un grupo del que no formas parte', async () => {
    await assertFails(
      setDoc(doc(como(BEA), 'users', ANA, 'notifications', 'n1'), {
        userId: ANA,
        groupId: GROUP_ID,
        fromUserId: BEA,
        type: 'expenseAdded',
        title: 'Falso',
        message: 'Falso',
        createdAt: '2026-07-18T10:00:00.000',
      }),
    );
  });
});
