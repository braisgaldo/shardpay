# ADR-0001 — Seguir en Flutter en lugar de migrar a Kotlin Multiplatform

- **Fecha:** 2026-08-31
- **Estado:** aceptado
- **Decide:** Brais Castiñeiras Galdo

## Contexto

La plantilla de proyecto expresa preferencia por **Kotlin Multiplatform con
Compose Multiplatform** y pide justificar en un ADR cualquier otra elección.

ShardPay ya existe: son unas 14 000 líneas de Dart repartidas en 31 ficheros,
con Firebase Auth, Firestore, Storage y Cloud Messaging integrados, ML Kit para
el reconocimiento de texto, `fl_chart` para las gráficas y Riverpod para el
estado. El encargo concreto de esta ronda (punto 14 de la plantilla) es
**hacerlo más eficiente y mejorar el lector de tickets**, no reescribirlo.

## Decisión

**Se mantiene Flutter.** No se migra a Kotlin Multiplatform.

## Motivos

### Esfuerzo de migración

Una migración a KMP no es portar la lógica: es rehacer la interfaz entera. Las
pantallas grandes de este proyecto —`group_detail_screen.dart` son 3 600
líneas— no tienen equivalente mecánico en Compose. La estimación honesta es de
varias semanas de trabajo, y el resultado sería, en el mejor de los casos, la
misma app que ya funciona.

Además habría que sustituir cuatro integraciones que en Flutter son un paquete y
en KMP no tienen equivalente de primera parte:

| Pieza | En Flutter | En KMP |
| --- | --- | --- |
| Firestore, Auth, Storage, Messaging | plugins oficiales de FlutterFire | SDK nativo por plataforma, o un envoltorio de terceros |
| Reconocimiento de texto | `google_mlkit_text_recognition` | ML Kit en Android, Vision en iOS, dos implementaciones |
| Gráficas | `fl_chart` | reescribir con Canvas |
| Cámara | `camera` | CameraX en Android, AVFoundation en iOS |

### El objetivo real ya está cubierto

El motivo de fondo de preferir KMP es **una sola base de código para Android,
iOS y escritorio**. Flutter ya lo da, y lo da hoy: el mismo Dart corre en las
tres plataformas sin `expect`/`actual`.

### El riesgo que sí había, se ha atajado

El peligro real de este proyecto no era el lenguaje, sino que la lógica de
negocio estuviera enterrada en los widgets. Lo estaba: el cálculo de saldos
vivía mezclado con la interfaz y el parser de tickets estaba pegado a ML Kit.

En esta ronda se ha extraído todo eso a `lib/core/`, que es **Dart puro sin
Flutter ni plugins**:

- `lib/core/receipts/` — parser de tickets
- `lib/core/expense_math.dart` — cálculo de saldos y liquidaciones
- `lib/core/backup_format.dart` — formato de copia de seguridad
- `lib/core/donation_policy.dart` — reglas del aviso de donación

Ese núcleo se compila y se prueba **sin Flutter**, con `dart test` a secas
(véase `docs/MANUAL-TECNICO.md`). Es el equivalente exacto de la regla dura de
la plantilla: *ninguna dependencia específica de plataforma en el código
compartido*. Y si algún día se decide migrar a KMP, ese núcleo es lo único que
habría que traducir, no la app entera.

### Tamaño del binario

No es un criterio decisivo aquí. Un AAB de Flutter con ML Kit ronda los 25-35 MB
por ABI; una app equivalente en KMP con ML Kit no baja mucho de ahí, porque el
peso lo pone el modelo de reconocimiento de texto, no el marco de trabajo.

## Consecuencias

### Buenas

- El trabajo de esta ronda va entero a lo que se pidió: eficiencia y lector de
  tickets.
- El núcleo probable de migración futura queda aislado y con pruebas.
- Escritorio queda a un `flutter build` de distancia (véase ADR-0007).

### Malas

- Se renuncia a la interfaz nativa de cada plataforma. En una app de listas y
  formularios, Material 3 pasa desapercibido en Android y resulta correcto pero
  no idiomático en iOS.
- Se hereda la dependencia del ciclo de versiones de Flutter y de los plugins de
  FlutterFire.

### A revisar

Si en el futuro se quiere una interfaz nativa por plataforma, la salida no es
reescribir en Compose Multiplatform sino **KMP con SwiftUI en iOS**, reutilizando
`lib/core/` traducido a Kotlin. Se revisará si aparece una razón de producto,
no antes.
