# ADR-0009 — Un grupo lo leen sus miembros y nadie más

- **Fecha:** 2026-08-31
- **Estado:** **aceptado e implementado**
- **Decide:** Brais Castiñeiras Galdo

## Contexto

Encontrado revisando `firestore.rules`. No era un fallo introducido en esa
entrega: venía del diseño original de la vista previa de invitaciones.

```
match /groups/{groupId} {
  allow get: if memberOfGroup() || signedIn();
  allow list: if signedIn() || canPreviewInvite();
  ...
}
```

Las dos líneas decían, en la práctica, que **cualquier usuario autenticado podía
leer cualquier grupo**:

- `allow get: ... || signedIn()` permitía leer un grupo por identificador aunque
  no se fuera miembro.
- `allow list: if signedIn()` permitía lanzar **cualquier consulta** sobre la
  colección `groups` y recibir los documentos que devolviera.

Y como el documento del grupo lleva dentro **todos sus gastos** (véase
[ADR-0005](0005-modelo-de-datos-y-limite-de-firestore.md)), lo que se exponía no
era el nombre del grupo: era el historial completo de gastos, con nombres,
importes, fechas, notas y correos de los miembros.

### Por qué estaba así

La app necesita enseñar una vista previa antes de entrar en un grupo: «Vas a
unirte a *Roadtrip Costa*, 4 miembros». Para eso, `_resolveInvite` consultaba

```dart
_firestore.collection('groups').where('inviteCode', isEqualTo: codigo).limit(1)
```

Y quien hacía esa consulta todavía **no era miembro**, así que la regla se relajó
para que funcionara.

### Un segundo agujero, encontrado al arreglar el primero

La regla `joiningGroupByInvite()` incluía `expenses` en la lista de campos que la
operación de entrada podía modificar. Es decir: **cualquiera con un código de
invitación podía reescribir o vaciar el historial de gastos del grupo entero** en
la misma escritura con la que entraba. Está cerrado en el mismo cambio, y hay una
prueba que lo fija.

### Un tercer hallazgo: salir de un grupo estaba roto

La regla de actualización exigía `request.auth.uid in request.resource.data.memberIds`,
es decir, **seguir siendo miembro después de escribir**. Salir de un grupo
consiste exactamente en lo contrario, así que «Salir del grupo» y «Eliminar mi
perfil» —que hace lo mismo en cada grupo del usuario— fallaban contra Firestore
de verdad.

No se había notado porque el modo de demostración es local y no pasa por las
reglas, y porque las reglas no se ejecutaban en ninguna prueba. Se añade
`leavingGroup()`, que sólo permite quitarte a ti mismo: la lista nueva mide uno
menos, no te contiene, y todo el que queda ya estaba antes.

### El PIN nunca fue una comprobación

`joinGroupByInvite` leía el grupo entero —incluido `joinPin`— y comparaba en el
móvil. Una comprobación que hace el cliente sobre datos que el cliente controla
no comprueba nada: bastaba con no hacerla. Sólo parecía funcionar porque las
reglas dejaban leer el grupo.

## Decisión

Separar la información pública de la invitación de los datos del grupo, y mover
al servidor lo que de verdad tenía que estar en el servidor.

### Colección `invites/{inviteCode}`

Un documento por código de invitación, con **sólo** lo que necesita la vista
previa: `groupId`, `groupName`, `iconKey`, `currency`, `memberCount`, los huecos
reservados libres (id y nombre), `isClosed` y `allowAnonymousJoin`.

Sin gastos, sin correos, sin identificadores de usuario y sin el PIN. La clase
`GroupInvitePreview` es la única que sabe construirla, y una prueba comprueba que
lo que serializa no contiene ninguna de esas cosas.

`allow get: if signedIn()`, `allow list: if false`: el código hay que conocerlo,
no descubrirlo.

### El PIN se verifica en las reglas

El móvil ya no puede leer `joinPin`. Manda `joinProof = base64(sha256("<pin>:<uid>"))`
y la regla lo recalcula con el PIN real:

```
request.resource.data.joinProof ==
  hashing.sha256(resource.data.joinPin + ':' + request.auth.uid).toBase64()
```

El uid va dentro del hash para que la prueba de una persona no sirva para otra.

Esto **no** convierte cuatro dígitos en un secreto fuerte: quien pueda escribir
contra el grupo puede probarlos todos. Es una barrera contra quien se encuentra
un enlace. Lo que impide leer el grupo es la regla de pertenencia, no el PIN.

### Reclamar un hueco reservado sin leer el grupo

Cuando alguien entraba diciendo «soy Marta», el móvil reescribía **todos** los
gastos del grupo cambiando `pending:marta` por su uid. Eso exige leer el grupo
entero antes de ser miembro, que es justo lo que ya no se puede.

Ahora la equivalencia se anota en `claimedSlots: { idDelHueco: uid }` y se
resuelve al leer, en `GroupLedger.canonicalId`. Sale mejor por tres lados: una
escritura de una línea en vez de reescribir el historial, ninguna lectura previa,
y el registro de gastos deja de mutar por algo que no es un gasto.

Un reclamo que apunte a alguien que no está en el grupo se ignora en todas
partes: si escondiera el hueco, la parte del gasto que le tocaba se quedaría sin
dueño y los saldos dejarían de sumar cero.

### El espejo lo mantiene el cliente, no una Cloud Function

**Aquí es donde esto se aparta de lo que se propuso en su día.** La propuesta
original sincronizaba `invites` con una Cloud Function `onWrite` sobre `groups`.
Se descartó por una razón dura: **Cloud Functions exige el plan Blaze**, y
[ADR-0002](0002-backend-y-usuarios.md) decía entonces que este proyecto vivía en
Spark y que no se usaba ningún servicio de pago de Google. Véase el epílogo al
final de esta sección: esa afirmación resultó no ser cierta.

En su lugar, la ficha la publica la propia app desde `_materializeGroup`, el
único punto por el que pasan todos los grupos que el usuario ve. Como también se
dispara la primera vez que un miembro abre un grupo antiguo, **sirve además de
migración**: los grupos que existían antes de que hubiera colección `invites`
publican su ficha solos, sin script aparte. Las reglas comprueban que quien
escribe la ficha es miembro del grupo al que apunta y que el código coincide.

Si la publicación falla, se traga el error: lo peor que pasa es que una
invitación enseñe un nombre viejo hasta el siguiente intento.

> **Epílogo.** Esta decisión destapó que `functions/index.js` ya contenía
> `pushUserNotification`, y que Cloud Functions también requiere Blaze: la
> afirmación de ADR-0002 de que todo cabía en Spark **no era cierta antes de
> este cambio**. Se resolvió en
> [ADR-0010](0010-plan-blaze-y-control-de-gasto.md): el proyecto pasa a Blaze
> con el gasto atado.
>
> Eso **no** cambia la decisión de arriba. El espejo lo sigue manteniendo el
> cliente: ahora se podría mover a una función, pero no compensa. La versión de
> hoy no depende de que una función esté caliente, migra sola los grupos
> antiguos, y su único defecto —que una ficha puede quedarse vieja si nadie
> abre el grupo— no lo sufre nadie, porque quien no abre el grupo tampoco
> comparte su invitación.

## Alternativa descartada

**Vista previa a través de una Cloud Function `onCall`.** Más limpia —nada
público— pero añade latencia al arranque del flujo de invitación, hace que
unirse a un grupo deje de funcionar si la función está fría o caída, y arrastra
el mismo problema de plan que la sincronización por función.

## Cómo se ha comprobado

Un fallo de este tipo no se ve leyendo el fichero de reglas por encima. La suite
`firestore-tests/rules.test.js` lo ejecuta contra el **emulador de Firestore**:
**44 comprobaciones**, incluidas las que reproducen exactamente los agujeros
descritos arriba. Corre en CI en el job `reglas` y bloquea el pipeline.

Lo que no necesita emulador está en `test/core/join_proof_test.dart`: el formato
de la prueba del PIN —fijado con el mismo valor que verifica el emulador— y que
la ficha pública no serializa PIN, gastos, correos ni identificadores.

## Consecuencias

- La vista previa de invitaciones funciona igual de cara al usuario.
- Un desconocido con un código ve el nombre del grupo, el icono, la divisa,
  cuánta gente hay y los huecos libres. Nada más.
- El PIN pasa a comprobarse donde se puede comprobar de verdad.
- Los gastos dejan de reescribirse al entrar alguien, por partida doble: ni la
  app lo hace, ni las reglas lo permiten.
- Salir de un grupo y borrarse la cuenta vuelven a funcionar.
- Una escritura más por grupo la primera vez que se ve, y otra cada vez que
  cambia su cara pública. En un plan gratuito, irrelevante.
- Los grupos dejan de ser legibles por quien no es miembro, que es lo que esta
  app debería haber hecho desde el principio.


---

## Epílogo: la prueba del PIN estuvo rota en producción

**2 de septiembre de 2026.** La 1.1.0 salió con esto roto y con las 38 pruebas en
verde. Entrar en un grupo por invitación fallaba con «permiso denegado» para
**unas tres de cada cuatro personas**.

La regla comparaba dos hashes que se calculan en sitios distintos:

```
request.resource.data.joinProof ==
  hashing.sha256(resource.data.joinPin + ':' + request.auth.uid).toBase64()
```

`toBase64()` de las reglas de Firestore devuelve base64 **urlsafe** —con `-` y
`_`—. `base64.encode` de Dart devuelve el **estándar** —con `+` y `/`—. Las dos
cadenas coinciden exactamente cuando el hash no contiene ninguno de esos dos
caracteres, y sobre 43 caracteres eso pasa una vez de cada cuatro. El resto de
las veces, el PIN correcto se rechazaba.

**Por qué no lo cogió la suite.** El valor esperado estaba fijado con un solo
usuario, `uid-bea`, y su hash es justo uno de los que no llevan `+` ni `/`. Una
prueba con un único caso de un espacio donde solo falla el 75 % es una prueba que
pasa por casualidad.

**Por qué tampoco lo cogió el ojo.** El emulador redacta las denegaciones como
`evaluation error at L190:24`, que suena a que algo ha reventado y no a que una
condición ha dado `false`. Se pierde un buen rato buscando una excepción que no
existe.

**El arreglo.** La prueba pasa a ser **hex en mayúsculas**, en los dos lados. Hex
no tiene variantes de alfabeto: solo mayúsculas o minúsculas, y eso se ve.
`toHexString()` de las reglas devuelve mayúsculas.

**La prueba que faltaba**, y que ahora existe en los dos niveles: barrer *muchos*
uids en vez de uno. Veinte contra el emulador, cien contra el formato en Dart.
Con veinte, que alguno caiga en el caso malo está prácticamente garantizado.

**Lo que hay que llevarse de aquí.** Cuando dos implementaciones tienen que
producir el mismo byte a byte, el valor de ejemplo no es la prueba: la prueba es
el barrido. Y conviene desconfiar de los formatos con más de un alfabeto posible
—base64, hex, URL-encoding, Unicode normalizado— antes de elegirlos para algo que
tiene que coincidir a través de una frontera.
