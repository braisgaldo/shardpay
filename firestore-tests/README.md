# Pruebas de las reglas de Firestore

Las reglas de `firestore.rules` son la única barrera entre los gastos de un grupo
y quien no es miembro. Hasta [ADR-0009](../docs/adr/0009-lectura-de-invitaciones.md)
tenían un agujero que dejaba leer **cualquier** grupo a **cualquier** usuario con
cuenta, y ese fallo no se ve leyendo el fichero por encima: hay que ejecutarlo.

Esta suite las ejecuta contra el emulador de Firestore.

## Ejecutar

```bash
cd firestore-tests
npm install
npm test
```

Hace falta **Node 18+** y **Java** (el emulador de Firestore es un `.jar`). No
hace falta ningún proyecto de Firebase real ni credenciales: todo corre en local.

Si el puerto 8080 está ocupado en tu máquina, cámbialo en `firebase.json` y pasa
el mismo valor en `FIRESTORE_EMULATOR_PORT`:

```bash
FIRESTORE_EMULATOR_PORT=8765 npm test
```

En Windows, `npm install` puede fallar por el límite de 260 caracteres de las
rutas si el repositorio está en un directorio profundo. La salida más rápida es
instalar en una carpeta corta (`C:\r`) y apuntar `SHARDPAY_RULES` al fichero de
reglas del repositorio.

## Qué cubre

- **Grupos**: solo los leen sus miembros, ni por identificador, ni barriendo la
  colección, ni consultando por código de invitación.
- **Invitaciones**: la ficha pública se lee con cuenta, no se puede enumerar, y
  no admite campos privados ni fichas bajo un código ajeno.
- **Entrar en un grupo**: hace falta probar que se conoce el PIN, y la operación
  de entrada no puede tocar los gastos, el PIN, el código, el dueño, los
  administradores ni el nombre.
- **Huecos reservados**: se reclama uno y solo uno, para uno mismo, y no se le
  puede quitar a quien ya lo tenía.
- **Miembros**: siguen pudiendo trabajar con normalidad, y **pueden salirse**
  del grupo sin poder llevarse por delante a nadie ni a los gastos, incluso
  cuando alguien había entrado por invitación.

La otra mitad de la comprobación está en `test/core/join_proof_test.dart`, que
fija el formato de la prueba del PIN sin necesidad de emulador.
