# Subir ShardPay a Google Play

Todo lo que hace falta para la ficha, en una carpeta, en el orden en que Play
Console lo pide.

> **Estado: el paquete ya está firmado con la clave de subida real.** Lo que
> queda antes de publicar está en la lista de más abajo; nada de eso impide
> subirlo a pruebas internas.

## Qué hay aquí

| Carpeta | Qué es | ¿En git? |
| --- | --- | --- |
| `app/` | El `.aab` firmado para Play y el `.apk` para instalar a mano, con sus SHA-256 | No, se regeneran |
| `graficos/` | Icono 512×512 y gráfico destacado 1024×500 | Sí |
| `capturas/` | Ocho capturas montadas a 9:16, listas para la ficha | Sí |
| `textos/` | Título, descripción corta y larga, un fichero por idioma | Sí |
| `politicas/` | Política de privacidad | Sí |
| `FIRMA.md` | Dónde está la clave, cómo se usa y qué pasa si se pierde | Sí |
| `seguridad-de-datos.md` | Respuestas del formulario de Seguridad de los datos | Sí |
| `clasificacion-de-contenido.md` | Respuestas del cuestionario de clasificación | Sí |

Los binarios están fuera de git a propósito: pesan 200 MB y se rehacen con un
comando. Lo que sí se versiona es lo que cuesta rehacer y hay que revisar.

## La firma

El `.aab` de `app/` va firmado con la clave de subida real:

```
Propietario: CN=Ghato Studio, OU=ShardPay, O=Ghato Studio, L=A Coruna, C=ES
SHA-1:       3D:E5:D5:5C:26:77:F8:95:DD:D4:55:08:FA:EE:A6:DA:0C:A2:1A:04
```

Se comprueba así, y conviene hacerlo antes de cada envío:

```bash
keytool -printcert -jarfile app/shardpay-1.1.0.aab | grep -i propietario
```

Si dijera `CN=Android Debug`, Gradle no encontró `android/key.properties` y Play
lo rechazaría. Todo el detalle —dónde está la clave, qué pasa si se pierde y el
paso de Play App Signing que no se ve fallar— está en [`FIRMA.md`](FIRMA.md).

## Antes de subir

- [x] Clave de subida creada, en formato PKCS12
- [x] `.aab` firmado con esa clave y verificado
- [x] SHA-1 y SHA-256 de la clave de subida registrados en Firebase
- [ ] **Guardar una copia del `.jks` y de `key.properties` fuera de este
      ordenador.** No hay ninguna otra: los dos están fuera de git
- [ ] SHA-1 de Play App Signing registrado en Firebase (después del primer envío;
      sin esto el acceso con Google falla para todo el mundo menos para ti)
- [ ] **App Check activado** — es la capa de control de gasto que falta desde que
      el proyecto está en Blaze ([ADR-0010](../adr/0010-plan-blaze-y-control-de-gasto.md))
- [ ] Presupuesto de 5 € con alertas configurado en Cloud Billing
- [ ] Política de privacidad publicada en una URL accesible

## Pasos en Play Console

### 1. Crear la aplicación

Nombre **ShardPay**, idioma predeterminado **español**, tipo **aplicación**,
**gratuita**. Ojo: de gratuita a de pago no se puede cambiar después.

> **El identificador se ata en la primera subida y no se suelta.** El de esta app
> es `com.ghatostudio.shardpay`. Si al subir el paquete sale *«El nombre del
> paquete debe ser …»* con otro identificador, es que esa ficha ya tiene uno
> reservado de una compilación anterior: no se puede cambiar ni en la app ni en
> la ficha. La salida es **crear una ficha nueva**, que quedará atada al
> identificador correcto. Pasó de verdad; está contado en
> [ADR-0003](../adr/0003-identificador-de-aplicacion.md).

### 2. Ficha principal

Play Console → **Presencia en Google Play** → **Ficha de Play principal**.

Pega desde `textos/es.md`. Después añade cada idioma con su fichero: `en`, `gl`,
`ca`, `eu`, `fr`, `it`, `pt`, `de`, `el`, `ru`, `ar`, `zh`, `ja`. Las longitudes
ya están comprobadas contra los límites.

Las **notas de la versión** van aparte, en el paso de crear la versión, y en otro
formato: Play las pide todas juntas etiquetadas por idioma. Están listas para
pegar en [`textos/notas-de-version.md`](textos/notas-de-version.md), las catorce
y dentro del límite de 500 caracteres.

Gráficos:

- **Icono**: `graficos/icono-512.png`
- **Gráfico destacado**: `graficos/destacado-1024x500.png`
- **Capturas de teléfono**: las ocho de `capturas/`, en orden

### 3. Contenido de la aplicación

- **Política de privacidad**: la URL pública. El texto está en
  `politicas/privacidad.md`.
- **URL de eliminación de cuentas**:
  `https://braisgaldo.github.io/shardpay/eliminar-cuenta.html`. Es un campo
  aparte del de la privacidad, y Play lo publica en la ficha. La fuente es
  [`docs/ELIMINAR-CUENTA.md`](../ELIMINAR-CUENTA.md), y cumple los tres
  requisitos que exige el formulario: nombra la app y el desarrollador, da los
  pasos exactos, y dice qué se borra y qué se conserva.
- **Anuncios**: no, la app no tiene.
- **Datos de inicio de sesión** (antes «Acceso a la app»): **sí, hay partes
  restringidas**, y hay que dar credenciales. Esto es fácil responderlo mal: la
  tentación es decir que no hace falta porque cualquiera se crea una cuenta desde
  la app, pero el propio formulario avisa de que Google **no crea cuentas para
  revisar**. Sin credenciales, el revisor se queda en la pantalla de acceso y
  rechaza la versión.

  Hay una cuenta de revisión creada para esto: `play.review@shardpay.app`. La
  contraseña va en el gestor de contraseñas, junto a la clave de firma. Si se
  pierde, se crea otra desde la propia app y se actualiza la ficha.

  En las instrucciones para el revisor conviene decirle que al entrar sale un
  tour guiado que recorre las funciones con un grupo de ejemplo, y que el lector
  de tickets está dentro de un grupo, en «Ticket con cámara» o «Subir ticket».
- **Clasificación de contenido**: respuestas en `clasificacion-de-contenido.md`.
- **Seguridad de los datos**: respuestas en `seguridad-de-datos.md`. Esto sale
  publicado en la ficha, así que las respuestas tienen que coincidir con lo que
  la app hace de verdad.
- **Público objetivo**: 18 y más. La app va de repartir dinero entre adultos.
- **Aplicación gubernamental**: no.
- **App financiera**: **no**. ShardPay no mueve dinero, no procesa pagos y no se
  conecta a ningún banco: calcula quién le debe qué a quién. Marcarla como
  aplicación financiera abre un proceso de verificación que no le corresponde.

### 4. Sobre la donación

Es el punto donde una ficha así se cae, así que conviene tenerlo claro antes de
que pregunten:

- La donación es un **enlace externo** a Revolut y ocurre **fuera de la app**.
- **No desbloquea absolutamente nada**: ni funciones, ni temas, ni contenido.
- Los textos evitan a propósito *comprar*, *pagar*, *desbloquear*, *pro*,
  *premium*, *suscripción* y *precio*, y en ningún sitio se habla de una
  «versión completa».
- El proyecto **no incluye ninguna biblioteca de facturación**, y hay un job de
  CI que falla si alguien la añade.

El razonamiento completo, con las citas de la política de Google, está en
[ADR-0008](../adr/0008-donacion-y-politicas-de-tienda.md).

### 5. Publicar

Empieza por **pruebas internas**, con tu propia cuenta. Instálala desde Play, no
por USB: es la única forma de comprobar que Play App Signing no ha roto el acceso
con Google.

Cuando eso funcione, producción.

## Regenerar todo

```bash
flutter build appbundle --release --dart-define-from-file=config/firebase.local.json
flutter build apk        --release --dart-define-from-file=config/firebase.local.json
python scripts/graficos_play.py    # icono, gráfico destacado y capturas a 9:16
```

Si compilas **sin** `--dart-define-from-file`, la app se publica en **modo de
demostración local**: funciona, parece normal y no guarda nada en la nube. No
avisa. Compruébalo siempre:

```bash
adb logcat | grep FirebaseApp     # "initialization successful"
```
