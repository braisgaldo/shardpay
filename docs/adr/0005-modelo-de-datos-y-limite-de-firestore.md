# ADR-0005 — Los gastos siguen dentro del documento del grupo, de momento

- **Fecha:** 2026-08-31
- **Estado:** aceptado, con revisión pendiente
- **Decide:** Brais Castiñeiras Galdo

## Contexto

Un grupo de ShardPay es **un solo documento de Firestore** que contiene, dentro,
la lista completa de sus gastos, cada uno con sus líneas y sus repartos.

Eso tiene una ventaja grande: leer un grupo es una lectura, escuchar un grupo es
una suscripción, y el cálculo de saldos tiene todos los datos delante sin
consultas adicionales.

Y tiene un techo: **un documento de Firestore no puede pasar de 1 MiB**.

## La cuenta

Un gasto con tres líneas y cinco repartos por línea ocupa unos 1,5 kB en JSON.
Con eso:

| Gastos | Tamaño aproximado | Estado |
| --- | --- | --- |
| 100 | ~150 kB | cómodo |
| 400 | ~600 kB | aceptable |
| 700 | ~1 MiB | **límite** |

Un grupo de viaje o de piso compartido difícilmente pasa de 200 gastos. Un grupo
de gente que comparte piso durante años, sí puede.

## Decisión

**Se mantiene el modelo actual en la versión 1.0.0**, y se anota aquí el punto de
ruptura y el plan.

## Por qué no se cambia ahora

Mover los gastos a una subcolección `groups/{id}/expenses/{id}` es la solución
correcta, pero toca el repositorio, las reglas de Firestore, todas las pantallas
que leen `group.expenses` y necesita una migración de los datos que ya existen.
Es un cambio de arquitectura, no una optimización, y el encargo de esta ronda era
eficiencia y lector de tickets.

Hacerlo a medias sería peor que no hacerlo.

## Lo que sí se ha hecho ahora

Se han atacado las consecuencias del modelo, que eran las que se notaban:

- **Escrituras dirigidas.** Añadir un gasto ya no reenvía el documento entero,
  solo el campo `expenses` y `updatedAt`. Además de gastar menos, deja de pisar
  los cambios que otro miembro haya hecho a los miembros o a los ajustes del
  grupo en el mismo instante.
- **Caché de deserialización.** El repositorio reutiliza el modelo ya construido
  de los grupos cuyo `updatedAt` no ha cambiado. Antes, tocar un gasto de un
  grupo obligaba a reconstruir todos los grupos del usuario.
- **Índice de cálculo.** Los saldos se calculan una vez por instantánea en lugar
  de una vez por miembro. Véase ADR-0006.

## Plan para la 1.1

1. Escribir los gastos **a la vez** en el documento y en la subcolección, durante
   una versión, para poder volver atrás.
2. Cambiar la lectura a la subcolección con paginación por fecha.
3. Migrar los grupos existentes con una función programada.
4. Dejar de escribir el campo del documento.
5. Actualizar `firestore.rules` para la subcolección.

## Señal de alarma

Si un grupo real se acerca a los 500 gastos, esto sube de prioridad. Merece la
pena instrumentarlo: registrar el tamaño del documento cuando pase de 500 kB.
