---
title: "ShardPay — Manual técnico"
subtitle: "Versión 1.0.0"
lang: es
---

# ShardPay — Manual técnico

Este documento incluye todo lo del [manual de usuario](MANUAL-USUARIO.md) y le
añade la arquitectura, las decisiones de diseño, la instalación, el despliegue y
la estrategia de pruebas con sus resultados.

Documentos relacionados:

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — mapa de capas y diagramas
- [`INSTALL.md`](INSTALL.md) — puesta en marcha, firma y despliegue
- [`GUIA-PUBLICACION.md`](GUIA-PUBLICACION.md) — tiendas
- [`adr/`](adr/) — decisiones de arquitectura, con sus alternativas descartadas

---

## 1. Panorama

| Pieza | Elección |
| --- | --- |
| Lenguaje | Dart 3.11+ |
| Marco | Flutter 3.35+ |
| Estado | Riverpod 2 |
| Backend | Firebase (Auth, Firestore, Storage, Messaging), capa gratuita |
| OCR | ML Kit en el dispositivo |
| Plataformas | Android (principal), iOS (portado, sin publicar) |
| Licencia | Apache-2.0 |

La decisión de seguir en Flutter y no migrar a Kotlin Multiplatform está
razonada en [ADR-0001](adr/0001-stack-y-portabilidad.md).

---

## 2. Estructura

```
lib/
├── app/            arranque, tema, preferencias, textos, proveedores
├── core/           DART PURO — sin Flutter, sin plugins, con pruebas
│   ├── receipts/   parser de tickets
│   ├── expense_math.dart
│   ├── backup_format.dart
│   ├── donation_policy.dart
│   ├── donation_config.dart
│   ├── app_info.dart
│   └── defaults.dart
├── models/         modelo de dominio y serialización
├── repositories/   Firestore + repositorio de demostración
├── services/       cámara, OCR, copias, notificaciones, almacenamiento
├── screens/        pantallas
└── widgets/        piezas reutilizables
```

**La regla de oro:** `lib/core/` no importa Flutter, ni `dart:ui`, ni ningún
plugin. Es lo que permite probar la lógica sin dispositivo, y lo único que habría
que traducir en una migración futura.

---

## 3. El lector de tickets, en detalle

Es la parte de esta entrega con más trabajo, así que va con detalle.

### 3.1 Por dónde pasa una foto

```
ReceiptScannerScreen   cámara en vivo: marco, linterna, enfoque al tocar
        ↓ ruta del fichero
ReceiptImageEditorScreen   recorte y giro
        ↓
TicketOcrService.scanReceipt
        ├─ 1ª pasada: ML Kit sobre la foto original
        │       ↓ ¿confianza ≥ 0,75 y cuadra con el total?  → listo
        └─ 2ª pasada (solo si no):
              ReceiptPreprocessor.enhance   → en otra isla
                 · orientación EXIF
                 · reescalado a 2000 px
                 · binarización de Sauvola
              ML Kit sobre la imagen realzada
              se elige la mejor de las dos lecturas
        ↓
OcrDocument.fromFragments   fragmentos → filas
        ↓
ReceiptParser.parse   → ReceiptScan
        ↓
diálogo de revisión con ReceiptScanSummary
```

### 3.2 Qué se cambió y por qué

#### Captura

**Antes:** `ImagePicker(source: camera)`, es decir, la cámara del sistema. El
usuario encuadraba a ojo y no se enteraba de que la foto había salido movida
hasta que fallaba la lectura.

**Ahora:** pantalla propia con vista previa en vivo, marco con proporción de
ticket, linterna, enfoque y exposición al tocar, y gestión del ciclo de vida
(Android puede quitar la cámara al pasar a segundo plano; hay que soltarla y
volver a pedirla, no dejar un controlador zombi).

Se pide `ResolutionPreset.veryHigh`: un ticket es una hoja larga y estrecha con
letra de 2 mm, y a 720p el OCR se queda sin píxeles por carácter.

#### Realce de imagen

**Antes:** el procesado corría en el hilo de interfaz y binarizaba con un
**umbral global fijo** (`luminancia >= 165`).

Dos problemas serios. El primero: una foto de 12 MP congelaba la app varios
segundos —el diálogo de «analizando» ni siquiera llegaba a animarse—. El
segundo, más grave: un umbral global no sirve para una foto con sombra, que es lo
normal al fotografiar un ticket sobre una mesa. La mitad iluminada queda toda
blanca y la sombreada toda negra.

**Ahora:** el realce corre en otra isla con `compute()` y usa **binarización de
Sauvola** sobre imágenes integrales:

```
t(x,y) = m(x,y) · (1 + k · (s(x,y)/R − 1))
```

donde `m` y `s` son la media y la desviación típica de una ventana alrededor de
cada píxel. Es exactamente el caso para el que se inventó la técnica: texto
oscuro sobre papel claro con iluminación desigual.

Las imágenes integrales dejan el coste en O(n) sea cual sea el tamaño de ventana.
Calcular la media píxel a píxel sería O(n·w²) y tardaría minutos.

La ventana se escala con la imagen (lado corto / 24, acotada entre 15 y 81 y
siempre impar): tiene que abarcar algo más que la altura de una línea de texto,
o el interior de las letras gruesas se blanquea y el OCR las ve huecas.

#### Segunda pasada solo cuando hace falta

**Antes:** se procesaban **siempre** las dos variantes —original y realzada— y se
elegía la mejor. El caso bueno, que es la mayoría, pagaba el doble de tiempo y de
batería sin ganar nada.

**Ahora:** se lee la original; si la lectura convence (confianza ≥ 0,75 **y**
cuadra con su propio total), se para ahí.

Entre dos lecturas manda la que cuadre con el total. Cuadrar es una señal
objetiva —el ticket confirma su propia aritmética—; la confianza es solo una
heurística.

#### Agrupación en filas

**Antes:** se agrupaban fragmentos por distancia entre centros verticales, con un
umbral en píxeles.

Falla con tickets torcidos, que son casi todos. Con cinco grados de inclinación,
el extremo derecho de un renglón queda más bajo que el centro del siguiente.

**Ahora:** se agrupa por **solape vertical** de las cajas, exigiendo un 40 % de
solape sobre la altura menor. Dos fragmentos del mismo renglón siguen solapándose
aunque sus centros estén desplazados.

Además se toman los **elementos** (palabras) y no las líneas de ML Kit: ML Kit
une en la misma «línea» el nombre y el precio aunque estén en extremos opuestos
del papel, y ahí se pierde la posición horizontal del importe.

#### Columna de precios

Señal nueva. Los importes de un ticket van alineados a la derecha en una columna.
El parser localiza esa columna con la mediana de los bordes derechos de los
números que terminan línea, y comprueba que al menos el 60 % de ellos caiga
dentro de la tolerancia; si no, decide que no hay columna y no la usa.

Un número que cae en la columna es casi seguro un precio. Uno que está en medio
de la línea suele ser un gramaje, un código o un precio unitario.

#### Palabras completas, no subcadenas

**Antes:** las palabras a ignorar se buscaban con `linea.contains('ud')`.

Eso descarta productos legítimos. «Go**ud**a» contiene «ud». «An**tip**asto»
contiene «tip». «Pr**iva**do» contiene «iva». Los tres se perdían.

**Ahora:** todo se compara con límites de palabra sobre el texto normalizado sin
acentos. Hay una prueba de regresión con esos tres productos exactos.

#### Dónde acaban los artículos

**Antes:** se cortaba en la **primera** aparición de «total», «subtotal»,
«tarjeta»…

Muchos tickets llevan «TOTAL COMPRA» en la cabecera. Con esos, el parser se comía
el ticket entero.

**Ahora:** el bloque de totales se busca **de abajo arriba** y solo en el 60 %
inferior del documento. Hay prueba de regresión.

#### Interpretación de importes

- **Separador decimal deducido del documento entero**, no de cada número. «1.234»
  es ambiguo en aislamiento; con todas las líneas delante, no.
- **Fechas, horas y porcentajes descartados** por contexto.
- **Signo negativo pospuesto** (`3,00-`), que es como muchas impresoras térmicas
  imprimen los abonos.
- **Cantidad y precio unitario**: `2 x CERVEZA 2,50 5,00` da cantidad 2, unitario
  2,50 y línea 5,00. Y si el ticket no imprime la cantidad, se deduce cuando el
  cociente entre los dos importes es un entero pequeño.
- **Descuentos** con importe negativo, que restan del reparto en lugar de
  desaparecer.

#### Cuadre contra el total

Lo que más se nota en una app de repartir gastos.

| Situación | Qué hace |
| --- | --- |
| Suma = total (±0,02) | Nada. Confianza alta |
| Suma > total, y sobra justo el importe de una línea | Quita esa línea (era el subtotal colado) y avisa |
| Suma < total | Añade una línea de ajuste con la diferencia y avisa |
| Suma < total y falta justo la propina detectada | Añade la propina como línea propia |
| Sin líneas pero con total | Una sola línea por el importe pagado, avisando |
| Suma > total sin explicación | Deja las líneas y avisa |

La razón de fondo: da igual que el OCR se deje un producto si el reparto acaba
sumando lo que de verdad se pagó. Sin esto, el grupo reparte una cifra que no es
la del ticket.

#### Higiene

Los ficheros temporales del realce **se borran siempre**, en un `finally`. Antes
se acumulaban en el directorio temporal, uno por cada ticket leído en toda la
vida de la instalación.

### 3.3 Avisos

El parser devuelve un `enum ReceiptWarning`, nunca texto: la app habla catorce
idiomas y los traduce la capa de interfaz.

---

## 4. Eficiencia

### 4.1 Cálculo de saldos

El problema, medido: `groupBalanceSummaries` tardaba **197 ms** en un grupo de 15
personas con 1000 gastos. Son doce fotogramas perdidos en cada reconstrucción de
la pantalla.

Dos causas:

1. `canonicalGroupUserId` llamaba a `group.visibleMembers`, un *getter* que
   **reconstruía la lista entera** —incluidos los objetos sintéticos de los
   invitados pendientes— en cada llamada. Y se llamaba en el bucle más interno:
   una vez por asignación de cada línea de cada gasto.
2. `groupBalanceSummaries` recorría todos los gastos del grupo **una vez por
   miembro**.

El coste era `O(miembros · gastos · líneas · asignaciones · miembros)`.

La solución es `GroupLedger`, un índice que se calcula una sola vez por instancia
de grupo:

- identificadores canónicos memoizados,
- saldo neto por miembro,
- matriz de deudas entre pares, antisimétrica.

Se guarda en un `Expando` sobre la instancia de `ExpenseGroup`. Como cada
instantánea de Firestore construye un objeto nuevo, la caché **se invalida sola**.

Además se eliminó `double.parse(valor.toStringAsFixed(2))`, que construía y
parseaba una cadena en cada redondeo, dentro de esos mismos bucles.

**Medición** (`dart run bin/bench.dart`, mismo grupo sintético en los dos
motores):

| Escenario | Antes | Ahora (frío) | Mejora | Mismo fotograma |
| --- | --- | --- | --- | --- |
| 6 personas, 100 gastos, 3 líneas | 3,2 ms | 1,9 ms | 1,7× | < 0,1 ms |
| 10 personas, 400 gastos, 4 líneas | 29,3 ms | 3,6 ms | 8,1× | < 0,1 ms |
| 15 personas, 1000 gastos, 5 líneas | 197,0 ms | 13,5 ms | **14,6×** | < 0,1 ms |

Diferencia máxima de saldo neto entre los dos motores: **0,0000 €**.

### 4.2 Otras mejoras

| Qué | Antes | Ahora |
| --- | --- | --- |
| Listas de miembros derivadas | recalculadas en cada acceso | una vez por instancia |
| Deserialización de grupos | todos los grupos en cada instantánea | solo los que cambian de `updatedAt` |
| Escritura de un gasto | documento entero | `expenses` + `updatedAt` |
| `outstandingExpenseDebts` | O(n²) buscando deudas abiertas | índice por par deudor-acreedor |
| Agregados de saldo global | recalculados en cada acceso | `late final` por instancia |
| Realce de imagen | hilo de interfaz | otra isla |
| Pasadas de OCR | siempre dos | una, y la segunda solo si hace falta |

La escritura dirigida tiene un beneficio que no es de rendimiento: al no reenviar
el documento entero, deja de pisar los cambios que otro miembro haya hecho a los
miembros o a los ajustes del grupo en el mismo instante.

---

## 5. Pruebas

### Estrategia

Todo lo que se puede probar sin dispositivo vive en `lib/core/` y **tiene
pruebas**. Es barato, corre en menos de un segundo y es lo que permite tocar el
parser sin miedo.

### Ejecutar

```bash
flutter test
```

O, para el núcleo puro, sin necesidad de Flutter:

```bash
dart test test/core
```

### Cobertura por suite

| Suite | Qué asegura |
| --- | --- |
| `core/receipts/receipt_parser_test.dart` | Separadores decimales, divisas, cantidades, precios unitarios, descuentos negativos, cuadre contra el total, ajuste, línea duplicada, comercio, fecha, geometría a dos columnas, ticket torcido, el **cruce aritmético del bloque de totales** contra el total impreso, y tres regresiones concretas |
| `core/expense_math_test.dart` | Reparto que suma 100 %, saldos que suman cero, matriz antisimétrica, liquidaciones que dejan todo a cero, identificadores de invitados, caché de listas |
| `core/backup_format_test.dart` | Ida y vuelta exacta, cabecera, JSON inválido, copia ajena, versión futura, fichero manipulado, copia vacía, suma de verificación, migraciones |
| `core/sample_ledger_test.dart` | Que el grupo de ejemplo del manual, la ayuda y el tour da exactamente los saldos, deudas, liquidaciones y estadísticas que se publican |
| `core/categories_test.dart` | Que una categoría desconocida nunca enseña su identificador interno al usuario |
| `core/join_proof_test.dart` | El formato de la prueba del PIN que verifican las reglas, y que la ficha pública de una invitación no serializa PIN, gastos, correos ni identificadores |
| `core/donation_policy_test.dart` | Las cinco reglas de aparición del aviso y su serialización |
| `app/theme_test.dart` | **Contraste AA en las trece paletas**, emparejamiento claro/oscuro, resolución del modo de tema, y que el color de acento **no** vale como color de texto sobre la superficie pero sí como borde de control |
| `app/localization_test.dart` | Los trece idiomas exigidos, RTL del árabe, respaldo de los idiomas romances al castellano, que `locales_config.xml` coincide con la lista de Dart, y **los plurales de «grupo» y «miembro»** |
| `widgets/rendering_test.dart` | La ilustración de la taza, el resumen de lectura, **las cuatro tablas del grupo de ejemplo** y las banderas se dibujan sin excepciones en las trece paletas y en árabe; descripciones para lectores de pantalla; se respeta «reducir animaciones» |
| `widgets/guided_tour_test.dart` | Que la tarjeta del tour cabe en una pantalla de 360×640 con la ilustración más alta, que «Siguiente» sigue siendo alcanzable y que se puede saltar |
| `firestore-tests/rules.test.js` | **Contra el emulador**: que un grupo solo lo leen sus miembros, que las invitaciones no se enumeran ni admiten campos privados, que entrar exige probar el PIN y no permite tocar gastos ni permisos, y que reclamar un hueco es para uno mismo y una sola vez |
| `models/app_models_test.dart` | Serialización del modelo |

**Total: 220 pruebas** sin dispositivo en unos 16 segundos, más **38 de reglas** contra el emulador de Firestore.

### La documentación como prueba

El manual de usuario y el tour guiado enseñan un grupo de ejemplo —«Roadtrip
Costa», cuatro personas, cuatro gastos, 216 €— con sus saldos, sus deudas
directas, sus liquidaciones y sus estadísticas. Esas cifras **no están escritas
a mano en el manual**.

El ejemplo vive en `lib/core/sample_ledger.dart` como un `ExpenseGroup` real, y
`test/core/sample_ledger_test.dart` lo pasa por el motor de cálculo de verdad
—`memberBalances`, `directBalancesForMember`, `settlementEdges`,
`categoryTotals`— y comprueba que sale exactamente lo que se publica:

| Lo que se enseña | Constante | Comprobado contra |
| --- | --- | --- |
| Las cuatro filas de gastos | `sampleExpenseRows` | los `ExpenseRecord` del grupo |
| Gasto total, 216 € | `sampleTotalSpend` | `totalGroupSpend` |
| Saldos +36 / −36 / +12 / −12 | `sampleNetBalances` | `memberBalances` |
| Las cinco deudas directas | `sampleDirectDebts` | `directBalancesForMember` |
| Los dos pagos que liquidan | `sampleSettlements` | `settlementEdges` |
| Lo que puso cada persona | `samplePaidByPerson` | los pagadores de cada gasto |
| El desglose por categorías | `sampleCategoryTotals` | `categoryTotals` |

La misma fuente alimenta las tres superficies: el manual, la pantalla de ayuda
(`_EjemploCompleto` en `help_screen.dart`) y los pasos del tour
(`tour_ledger_example.dart`). Si alguien cambia el algoritmo de liquidación y el
ejemplo deja de cuadrar, **la suite se pone roja antes de que la documentación
mienta**, en vez de descubrirse meses después con un usuario delante.

Hay dos comprobaciones que no son de igualdad y son las que dan valor al
ejemplo: que los saldos suman cero, y que aplicar los pagos propuestos deja a
las cuatro personas a cero. Es decir, que el ejemplo no solo coincide con el
código: además está bien.

Los importes están elegidos para que el reparto entre cuatro caiga en euros
redondos. Un reparto entre tres arrastra céntimos de 33,33 que distraen de lo
que se está explicando y obligan a escribir «aproximadamente» en un manual que
va justamente de cuadrar cuentas.

### Regresiones que están fijadas por prueba

1. **Cabecera con «total»** — `no se corta cuando la cabecera contiene la palabra
   total`. El parser anterior cortaba en la primera aparición.
2. **Palabras clave como subcadena** — `no descarta productos que contienen
   palabras clave como subcadena`, con «Gouda», «Antipasto» y «Salón Privado».
3. **Descuentos negativos** — `trata el descuento como importe negativo`.
4. **Ticket torcido** — `agrupa en la misma fila fragmentos de un ticket
   torcido`, con el importe 6 px por debajo del nombre.
5. **Total mal leído, corregido con la aritmética del ticket** — `corrige el
   total cuando las lineas y el subtotal se dan la razon`. El móvil leyó
   `TOTAL 52,36` como `52,00`; las líneas y el subtotal impreso coincidían en
   47,60 y el IVA en 4,76, así que el total era el número raro.
6. **Ida y vuelta de la copia** — `la ida y vuelta devuelve exactamente el mismo
   estado`, comprobando saldos calculados, no solo campos.
7. **Cuentas publicadas** — `las liquidaciones son las dos que dice la
   documentación` y `las deudas directas son las cinco que dice la
   documentación`. Fija el ejemplo del manual contra el motor.
8. **Tarjeta del tour desbordada** — `la tarjeta con ilustración cabe en una
   pantalla de 360x640`. Antes del tope de altura, la tarjeta se salía por abajo
   72, 126 y hasta 488 px según el paso, y dejaba «Siguiente» y «Saltar el tour»
   fuera de la pantalla. En un móvil pequeño, el tour no se podía ni terminar ni
   saltar.

### Resultado de la última ejecución

```
00:16 +220: All tests passed!
```

Análisis estático del núcleo: **0 problemas**.

### Lo que NO está probado y por qué

- **Widgets y pantallas.** No hay pruebas de widget. Es una carencia real y está
  anotada abajo.
- **La cámara y ML Kit.** Necesitan dispositivo. Lo que sí está probado es todo
  lo que ocurre después de que ML Kit devuelve texto, que es donde estaban los
  fallos.
- **Firestore.** No hay pruebas contra el emulador.

---

## 6. Estado de la entrega

Lo que está hecho y verificado, y lo que no. Sin adornos.

### Verificado, con Flutter 3.47.2 y Dart 3.13.2

```
flutter pub get     resuelve las 4 dependencias nuevas
dart analyze        No issues found!          (0 errores, 0 avisos, 0 infos)
dart format         lib/core y test/core sin cambios pendientes
flutter test        164 tests · All tests passed!
```

- **Análisis estático limpio en todo el proyecto.** Se corrigieron un error de
  compilación, dos avisos y 44 avisos menores.
- **220 pruebas en verde**, incluidas 146 nuevas: parser de tickets, cálculo de
  saldos, copias de seguridad, política de donación, contraste de las paletas,
  idiomas y renderizado de widgets.
- **El contraste AA está comprobado en las trece paletas**, no supuesto. La
  comprobación encontró un fallo real y lo obligó a arreglar: `colorOn` decidía
  el color del texto con `ThemeData.estimateBrightnessForColor`, que va por un
  umbral de luminancia y no por contraste. Ponía texto blanco sobre acentos
  claros en **las trece paletas**; el naranja del tema por defecto daba 3,68:1
  cuando AA exige 4,5:1.
- La mejora de rendimiento del cálculo de saldos está **medida**, no estimada, y
  se ha comprobado que los resultados son idénticos al céntimo a los del motor
  anterior.
- El fichero `locales_config.xml` y la lista de idiomas de Dart se comprueban
  entre sí en una prueba: no se pueden separar sin que algo falle.
- Las políticas de Google Play y App Store se han consultado en su fuente oficial
  el 2026-08-31 y están citadas literalmente en
  [ADR-0008](adr/0008-donacion-y-politicas-de-tienda.md).

### No verificado

Este entorno no tiene **SDK de Android, ni Java, ni un dispositivo conectado por
ADB**, así que nada de lo que necesita compilar para Android o ejecutarse en un
teléfono se ha podido probar.

Queda pendiente, y hay que hacerlo antes de dar la versión por buena:

- [ ] `flutter build apk` / `flutter build appbundle` (necesita el SDK de Android).
- [ ] Instalar y ejecutar en un dispositivo real.
- [ ] **Probar el lector de tickets con tickets de verdad.** Las pruebas cubren
      la interpretación del texto; lo que no se ha podido probar es la cadena
      completa cámara → ML Kit → parser sobre papel real.
- [ ] Capturas del dispositivo para el manual y para la ficha de tienda.
- [ ] Capturas del panel de donación en las paletas y en RTL. El renderizado
      está cubierto por pruebas de widget en las trece paletas y en árabe, pero
      una prueba no sustituye a mirarlo.
- [ ] `./gradlew :app:dependencies | grep -i billing` (debe salir vacío).
- [ ] Ciclo completo en dispositivo: exportar → borrar datos → importar. La ida
      y vuelta del formato sí está probada.
- [ ] TalkBack en las pantallas principales.
- [ ] **Activar App Check.** Es la capa de control de gasto que falta desde que
      el proyecto está en Blaze ([ADR-0010](adr/0010-plan-blaze-y-control-de-gasto.md)).

El flujo de `.github/workflows/ci.yml` ejecuta la compilación de Android y la
comprobación de facturación en cada envío, así que esos dos se cubren solos en
cuanto se suba la rama.

### Deudas técnicas conocidas

| Deuda | Impacto | Dónde |
| --- | --- | --- |
| El proyecto está en **Blaze**, así que no hay tope automático de gasto | Un fallo en bucle o un pico de uso pueden generar factura. Mitigado por reglas, `maxInstances`, presupuesto y corte manual; falta App Check | [ADR-0010](adr/0010-plan-blaze-y-control-de-gasto.md) |
| Los gastos viven dentro del documento del grupo (techo de 1 MiB) | Grupos con más de ~700 gastos | [ADR-0005](adr/0005-modelo-de-datos-y-limite-de-firestore.md) |
| Las pruebas de widget cubren piezas sueltas, no flujos completos | Una regresión en el flujo de crear un gasto no se detecta sola | `test/widgets/` |
| `group_detail_screen.dart` son 3 600 líneas | Difícil de mantener | — |
| Los catálogos de traducción cubren 180 cadenas; lo que se añada nuevo cae al inglés en los idiomas sin traducción explícita | Textos en inglés dentro de una interfaz en árabe o griego | `lib/app/app_text.dart` |
| El comprobador de formato solo cubre `lib/core`; extenderlo necesita antes un commit dedicado a formatear | Estilo desigual en el resto del árbol | `.github/workflows/ci.yml` |
| La tipografía se descarga en tiempo de ejecución con `google_fonts` | Petición a `fonts.gstatic.com` en el primer arranque, y sin red la app usa la fuente de respaldo | `lib/app/theme.dart` |
