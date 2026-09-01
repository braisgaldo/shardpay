# Decisiones de arquitectura

Un ADR (*Architecture Decision Record*) es una nota corta que explica **por qué**
se tomó una decisión, qué alternativas se descartaron y qué consecuencias tiene.
Sirve para que dentro de un año nadie —incluido uno mismo— tenga que reconstruir
el razonamiento a partir del código.

| # | Decisión | Estado |
| --- | --- | --- |
| [0001](0001-stack-y-portabilidad.md) | Seguir en Flutter en lugar de migrar a Kotlin Multiplatform | aceptado |
| [0002](0002-backend-y-usuarios.md) | Firebase como backend, y por qué aquí sí hace falta | aceptado, revisado en parte por [0010](0010-plan-blaze-y-control-de-gasto.md) |
| [0003](0003-identificador-de-aplicacion.md) | Mantener `com.ghatostudio.shardpay` como identificador | aceptado |
| [0004](0004-formato-de-copia-de-seguridad.md) | `.shardpay.bak` es JSON comprimido con gzip | aceptado |
| [0005](0005-modelo-de-datos-y-limite-de-firestore.md) | Los gastos siguen dentro del documento del grupo, de momento | aceptado, revisión pendiente |
| [0006](0006-permisos-y-privacidad.md) | Permisos: solo dos, y los dos justificados | aceptado |
| [0007](0007-escritorio-e-ios.md) | Escritorio e iOS: qué funciona hoy y qué falta | aceptado |
| [0008](0008-donacion-y-politicas-de-tienda.md) | La donación no desbloquea nada, y por eso no es una compra | aceptado |
| [0009](0009-lectura-de-invitaciones.md) | Un grupo lo leen sus miembros y nadie más | aceptado e implementado |
| [0010](0010-plan-blaze-y-control-de-gasto.md) | El proyecto pasa al plan Blaze, con el gasto atado | aceptado |

## Los tres que más conviene leer

- **[0001](0001-stack-y-portabilidad.md)** si te preguntas por qué esto es
  Flutter y no Kotlin Multiplatform, que era la preferencia de partida.
- **[0005](0005-modelo-de-datos-y-limite-de-firestore.md)** si vas a tocar el
  almacenamiento: hay un techo conocido y un plan escrito.
- **[0008](0008-donacion-y-politicas-de-tienda.md)** antes de tocar nada de la
  donación. Hay una regla dura ahí que sostiene que la app pueda estar en las
  tiendas sin sistema de facturación.

## Cómo añadir uno

Numeración correlativa, nombre en kebab-case y esta estructura:

```markdown
# ADR-000N — Título en una frase que ya diga la decisión

- **Fecha:**
- **Estado:** propuesto | aceptado | sustituido por ADR-000M
- **Decide:**

## Contexto
Qué problema hay. Sin opinión todavía.

## Decisión
Qué se hace. En presente y en afirmativo.

## Motivos
Por qué eso y no lo otro. Aquí van las alternativas descartadas, con su motivo.

## Consecuencias
Lo bueno, lo malo y lo que habrá que revisar más adelante.
```

Un ADR **no se edita** cuando la decisión cambia: se escribe uno nuevo que
sustituya al anterior, y el viejo se marca como sustituido. La historia de por
qué se pensó algo es tan útil como la decisión final.
