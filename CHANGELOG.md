# Registro de cambios

Todos los cambios reseñables de ShardPay se anotan aquí.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el
versionado sigue [SemVer](https://semver.org/lang/es/).

## [1.2.1] — 2026-09-02

### Corregido

- **El paquete declaraba el permiso de micrófono**, así que Google Play le decía
  al usuario que una app de repartir cuentas puede grabar audio. No estaba en el
  manifiesto de ShardPay: lo declara `camera_android_camerax`, que también sabe
  grabar vídeo, y entraba al combinarse los manifiestos. Con él se colaban
  `READ_EXTERNAL_STORAGE` y `WRITE_EXTERNAL_STORAGE`. Los tres se quitan con
  `tools:node="remove"`. Quitarlos es seguro: la cámara se abre con
  `enableAudio: false` y las copias de seguridad van por el selector de ficheros
  del sistema.
- **Se guardaba el token de notificaciones de quien las rechazaba.** Se pedía el
  permiso y no se miraba el resultado, así que el token acababa en Firestore
  aunque no hubiera forma de enviar nada a ese dispositivo. Ahora solo se guarda
  si el permiso está concedido, lo que además convierte esa recogida en
  **opcional** en la ficha de Play en vez de obligatoria.

## [1.2.0] — 2026-09-02

### Añadido

- **Quitar a alguien de un grupo.** Quien administra tiene ahora una X en la
  etiqueta de cada persona, en «Personas del grupo». Hasta ahora sólo se podía
  salir uno mismo, cerrar el grupo o borrarlo: si alguien entraba con un código
  que no le tocaba, o dejaba de pintar algo, no había forma de sacarlo. La
  participación se archiva con su nombre, no se borra, porque los gastos que pagó
  siguen contando en los saldos del resto.
- **Página pública de eliminación de cuenta**, en
  `braisgaldo.github.io/shardpay/eliminar-cuenta.html`. Google Play la exige como
  campo propio de la ficha, con los pasos y el detalle de qué se borra y qué se
  conserva.

### Corregido

- **Entrar en un grupo por invitación fallaba para tres de cada cuatro
  personas.** La regla de Firestore comparaba el hash del PIN en base64
  **urlsafe** —lo que devuelve `toBase64()` allí— contra el base64 **estándar**
  que produce Dart. Coinciden solo cuando el hash no lleva `+` ni `/`, o sea una
  vez de cada cuatro; el resto daba «permiso denegado» sin más explicación. La
  prueba pasa a ser hex en mayúsculas, que no tiene variantes de alfabeto.

  Las 38 pruebas de reglas estaban en verde porque fijaban el valor esperado con
  **un solo usuario**, y su hash resulta ser de los que no llevan esos
  caracteres. Ahora se barren veinte uids contra el emulador y cien contra el
  formato. Todo el análisis está en el epílogo de
  [ADR-0009](docs/adr/0009-lectura-de-invitaciones.md).
- **Un miembro archivado seguía contando como miembro.** Un grupo con una persona
  y un hueco libre decía «3 miembros» después de expulsar a alguien, porque el
  contador miraba `members` en bruto en vez de los activos. Afectaba también al
  número que se le enseña a quien está decidiendo si entra.
- **Borrarse la cuenta dejaba el nombre y el correo en cada grupo.** La
  participación se marcaba como archivada, pero conservaba nombre, correo y foto,
  a la vista de los demás miembros. La política de privacidad decía —y dice— que
  desaparecen; ahora desaparecen de verdad. El identificador interno sí se
  conserva: los gastos apuntan a él, y quitarlo rompería los saldos de todo el
  grupo.
- **Borrarse la cuenta dejaba las notificaciones huérfanas.** Borrar el documento
  de usuario en Firestore no borra sus subcolecciones, así que las notificaciones
  —que llevan dentro de qué grupo son y quién las provocó— seguían existiendo
  colgando de un documento que ya no estaba. Ahora se barren antes.

## [1.1.0] — 2026-09-01

### Añadido

- **`scripts/tickets_de_prueba.py`**, que genera cuatro tickets de prueba como
  imágenes: uno normal, uno con cantidades y precio unitario, uno con un
  descuento en negativo y uno cuya suma **no** cuadra con el total impreso.
  Probar el lector con un ticket de papel delante es lento y no se puede repetir
  igual dos veces; estos salen siempre iguales, así que un fallo de lectura se
  puede reproducir tal cual.
- **Carpeta `docs/google_play/`** con todo lo que Play pide: el `.aab` y el
  `.apk`, el icono de 512, el gráfico destacado de 1024×500, ocho capturas
  montadas a 9:16, los textos de la ficha en catorce ficheros —uno por idioma—,
  la política de privacidad, las respuestas del formulario de Seguridad de los
  datos y las del cuestionario de clasificación, y una guía paso a paso.
- **`scripts/crear-clave-subida.ps1`**, que genera la clave de subida. Sin ella,
  la compilación de publicación se firma con la clave de **depuración** y Play
  la rechaza: no es un aviso, es un rechazo.
- **`scripts/graficos_play.py`**, que genera el icono y el gráfico destacado con
  la paleta de la app, y monta las capturas al formato que Play acepta.
- **220 pruebas automáticas**, 146 de ellas nuevas: parser de tickets, cálculo de
  saldos, formato de copia de seguridad, política de donación, contraste de las
  paletas, idiomas y renderizado de widgets. Todas corren sin dispositivo.
- **Pantalla de captura de tickets propia**, con vista previa en vivo, guía de
  encuadre, linterna, enfoque al tocar y aviso de recorte. Antes se llamaba
  directamente a la cámara del sistema y no había forma de saber si la foto
  había salido movida hasta que fallaba la lectura.
- **Cuadre del ticket contra su propio total.** Cuando la suma de las líneas no
  coincide con el total impreso, se añade una línea de ajuste para que el
  reparto sume lo que de verdad se pagó, y se avisa de ello.
- **Detección de cantidad y precio unitario** en las líneas del tipo
  `2 x CERVEZA 2,50 5,00`, incluida la deducción de la cantidad cuando el ticket
  no la imprime.
- **Detección de comercio, fecha y divisa** del ticket.
- **Resumen honesto de la lectura** en el diálogo de revisión: total impreso,
  suma de líneas, calidad de la lectura y avisos, todo traducido.
- Opción de tema **«Seguir el sistema»**, además de claro y oscuro fijos. Cada
  paleta tiene su hermana del brillo contrario, así que cambiar de claro a
  oscuro no cambia de estética.
- Cuatro idiomas nuevos: **árabe** (con disposición de derecha a izquierda),
  **griego**, **catalán** y **euskera**. La app queda en catorce idiomas.
- Selector de idioma con bandera —o icono neutro de idioma para el inglés y el
  árabe— y el nombre de cada idioma escrito en su propio idioma.
- **Exportación e importación de datos** en un fichero propio `.shardpay.bak`
  (JSON comprimido con gzip, con cabecera de versión y suma de verificación).
  La importación valida el fichero antes de tocar nada y guarda una copia
  automática del estado anterior.
- Asociación de la extensión `.shardpay.bak` y su tipo MIME, para poder abrir
  una copia desde el gestor de archivos.
- **Panel de «invítame a un café»**: bottom sheet con ilustración vectorial
  propia, vapor animado, código QR generado en local y copia del enlace. No
  desbloquea absolutamente nada.
- **Grupo de ejemplo comprobado por prueba.** El tour, la pantalla de ayuda y el
  manual de usuario explican el mismo caso —«Roadtrip Costa», cuatro personas,
  cuatro gastos, 216 €— con sus saldos, sus cinco deudas directas, los dos pagos
  que lo liquidan y el desglose por categorías. Esas cifras no están escritas a
  mano: salen de `lib/core/sample_ledger.dart` y una prueba las pasa por el
  motor de cálculo de verdad. Si alguien toca el algoritmo de liquidación, la
  suite se pone roja antes de que la documentación mienta.
- **Vista de deudas directas en la ayuda y en el tour**: quién le debe qué a
  quién gasto a gasto, junto a los pagos que propone la app. Enseñar las dos
  listas seguidas —cinco deudas por 54 € que se quedan en dos pagos por 48 €—
  es la forma más rápida de que se entienda qué hace el botón de liquidar y por
  qué nadie gana ni pierde un céntimo por el camino.
- **Pruebas de las reglas de seguridad contra el emulador de Firestore**: 37
  comprobaciones que reproducen los agujeros cerrados y vigilan que no vuelvan.
  Corren en la CI y la bloquean. Un fallo de reglas no se ve leyendo el fichero.
- **Once capturas tenían el marco verde de grabación de pantalla** que pinta
  Android, y son las que van a la ficha de la tienda. No se vio hasta maquetarlas
  en el manual, donde quedaba como una raya de color al lado del texto. Se
  recortaron con `scripts/limpiar_capturas.py`, y la CI ahora falla si vuelve a
  aparecer.
- **El manual de usuario lleva veinte capturas de la app**, colocadas en la
  sección que explican: la pantalla de acceso, el tour, la lista de grupos, el
  lector de tickets, la vista de deudas, las estadísticas, los selectores de
  paleta e idioma y la interfaz en árabe. Van recortadas —fuera la barra de
  estado y la de navegación del móvil, que no explican nada— e **incrustadas en
  el propio documento**, así que el HTML y el PDF son un fichero suelto que se
  puede mandar sin una carpeta de imágenes detrás.
- **Manuales en HTML y PDF** con portada, índice, resaltado de sintaxis y estilo
  propio, generados por `docs/build_docs.py` desde el mismo Markdown que se
  versiona. Se publican en el sitio y se adjuntan a cada Release.
- **Tour guiado** en lugar de la hoja de manual. Cada explicación aparece
  encima del botón del que habla, recortando el velo justo sobre él, así que se
  aprende dónde están las cosas y no solo qué hacen. Sale una vez la primera
  vez, se puede saltar, y **se relanza desde Ajustes → ShardPay → Ver el tour
  guiado**.
- Pantallas de **Ayuda** y **Acerca de** con versión, compilación, commit,
  licencia, licencias de terceros, privacidad y contacto.
- Botón de **compartir la app** con texto localizado.
- Ajustes reorganizados como punto único de entrada a tema, idioma,
  notificaciones, datos, compartir, donación, ayuda y «Acerca de». **Las
  secciones van plegadas**, cada una con su valor actual resumido en el
  encabezado —la paleta elegida, el idioma, cuántos avisos hay encendidos—, y
  las trece paletas y los catorce idiomas son ahora **selectores desplegables**
  en lugar de listas completas. La pantalla pasa de medir dos pantallazos a
  caber casi entera de una vez.
- Un **trinquete de colores a fuego**: una prueba fija cuántos literales de
  color tiene cada fichero de interfaz y falla si alguien sube el número. El
  código nuevo tiene que usar tokens del tema.
- Idioma por app en Android 13 o superior (`locales_config.xml`).
- Configuración de firma de publicación leída de `android/key.properties`, fuera
  del repositorio.
- Flujos de integración continua: análisis, pruebas y compilación en cada envío;
  publicación con AAB y documentos adjuntos; publicación de la página del
  proyecto y de la política de privacidad en GitHub Pages.

### Cambiado

- **El lector de tickets cruza la aritmética que el propio ticket imprime.** Un
  ticket trae la comprobación dentro: `subtotal + impuestos + propina − descuento
  = total`. Son los mismos números dichos de dos maneras, y el reconocimiento de
  texto falla en **uno** cada vez, no en todos. Si las líneas de artículos y el
  subtotal impreso coinciden entre sí y el total no cuadra con ellos, el total es
  el número equivocado y se corrige con la suma. Todo en el dispositivo, sin
  ninguna llamada a ningún sitio.

  Lo motivó un caso real: en un ticket de prueba con `TOTAL 52,36`, el móvil leyó
  `52,00`. El cuadre posterior hacía su trabajo pero contra un total equivocado y
  añadía una línea de ajuste de 4,40 € que no significaba nada. Con la corrección
  el ajuste vale 4,76 €, que es exactamente el IVA impreso.

  Es deliberadamente conservador: sin subtotal impreso, o si el subtotal no
  coincide con las líneas, o si la desviación es grande, no toca nada. Mejor un
  total dudoso que un total inventado.
- **`storeFile` en `key.properties` se resuelve desde `android/`**, que es donde
  está el propio fichero. Gradle lo resolvía contra `android/app/` y el error era
  «Keystore file not found» sin decir contra qué directorio había buscado.
- La ficha de la tienda ya no lleva la línea «Código abierto: github.com/…» al
  final de la descripción, en ninguno de los catorce idiomas. La ficha es para
  quien va a instalar la app; el repositorio sigue enlazado desde la web y desde
  «Acerca de».
- **El acceso real está activado y verificado en un dispositivo.** Crear cuenta,
  cerrar sesión, volver a entrar y eliminar la cuenta funcionan contra Firebase
  Auth y Firestore de verdad, no contra el modo de demostración. Hizo falta
  habilitar el proveedor de email/contraseña en el proyecto, que estaba
  deshabilitado y hacía fallar el alta con un `OPERATION_NOT_ALLOWED` que la app
  sí explicaba correctamente.
- **Las reglas de seguridad están desplegadas en el proyecto**, no solo en el
  repositorio. Hasta ahora el agujero de [ADR-0009](docs/adr/0009-lectura-de-invitaciones.md)
  seguía abierto en producción aunque estuviera arreglado en el código.
- **Salir de un grupo en el que alguien había entrado por invitación fallaba.**
  `leaveGroup` y `deleteUserProfile` reescriben el documento entero, y eso borra
  el campo `joinProof` que deja la operación de entrar; la regla de salida no
  contemplaba esa clave. Encontrado al revisar el borrado de cuenta contra las
  reglas nuevas, y fijado con una prueba contra el emulador.
- El texto de la pantalla de alta decía que Google se podría usar «en cuanto la
  infraestructura quede activada». Ya lo está: los dos proveedores funcionan.
- **Compartir e invitar a un café pasan a ser botones de verdad en Ajustes.**
  Eran dos filas de lista entre «Ayuda» y «Acerca de», y se perdían: había que
  acertar a pulsar un renglón que no parecía pulsable. Ahora son dos botones a
  todo el ancho, «Compartir ShardPay» y «Invítame a un café · 1 €». El segundo
  va relleno y el primero con contorno: con el primero tonal, en varias paletas
  salía del mismo naranja que el relleno y los dos competían. El texto del botón
  con contorno **no** va en color de acento, porque medido con `contrastRatio` da
  3,58:1 sobre la superficie clara y AA pide 4,5:1; el acento se queda en el
  borde, que como elemento no textual solo necesita 3:1. Hay dos pruebas nuevas
  que fijan las dos cosas en las trece paletas. El texto honesto no cambia:
  gratis, sin anuncios, y no desbloquea nada.
- **La cabecera de un grupo ya no se corta.** El título son hasta tres líneas
  —nombre, descripción y «N miembros · invite CÓDIGO»— y la barra solo daba para
  dos, así que la tercera aparecía partida por la mitad en todas las capturas de
  esa pantalla.
- **Un nombre largo sin espacios ya no parte a mitad de palabra** en la vista de
  deudas del grupo, ni descoloca el importe de la fila.
- **El proyecto pasa al plan Blaze**, con el gasto atado por cinco capas
  ([ADR-0010](docs/adr/0010-plan-blaze-y-control-de-gasto.md)). No es un cambio
  de rumbo: `functions/index.js` ya usaba Cloud Functions, que Spark no permite,
  así que la documentación llevaba tiempo afirmando algo que no era cierto. Se
  corrige y se documenta qué limita el consumo, empezando por las reglas de
  seguridad: desde que nadie puede barrer la colección de grupos, tampoco puede
  hacerlo para generar factura.
- **Una categoría desconocida ya no enseña su identificador interno.** En la
  pantalla de estadísticas aparecía «coffee» entre «Comida» y «Transporte»,
  porque cuando no se encontraba la categoría se pintaba el `categoryId` crudo.
  Ahora cae en «Otros», traducido a los catorce idiomas. Se descubrió haciendo
  las capturas de la ficha de la tienda.
- **Un grupo lo leen sus miembros y nadie más.** Las reglas de Firestore
  permitían que cualquier usuario autenticado leyera **cualquier** grupo, y como
  el documento de un grupo lleva dentro todos sus gastos, eso era el historial
  completo —importes, fechas, notas y correos— de todo el mundo. Al arreglarlo
  apareció un segundo agujero: la operación de entrar por invitación podía
  reescribir o vaciar los gastos del grupo. Los dos están cerrados y fijados por
  prueba. Véase [ADR-0009](docs/adr/0009-lectura-de-invitaciones.md).
- **«Salir del grupo» y «Eliminar mi perfil» vuelven a funcionar.** Las reglas
  exigían seguir siendo miembro después de escribir, y salirse es exactamente lo
  contrario, así que las dos operaciones fallaban contra Firestore. No se veía
  porque el modo de demostración no pasa por las reglas y porque las reglas no
  se ejecutaban en ninguna prueba.
- **El PIN de un grupo se comprueba en el servidor.** Antes la app leía el grupo
  entero, PIN incluido, y comparaba en el móvil: una comprobación que hace el
  cliente con datos que el cliente controla no comprueba nada. Ahora el móvil
  manda una prueba criptográfica y la verifican las reglas.
- **Reclamar un hueco reservado ya no reescribe los gastos.** Cuando alguien
  entraba diciendo «soy Marta», la app reescribía todas las líneas del grupo. Se
  anota la equivalencia y se resuelve al calcular: una escritura de una línea en
  vez de todo el historial, y sin necesidad de leer el grupo antes de ser
  miembro.
- **El aviso de «modo demo local» solo sale en compilaciones de depuración.** Era
  un diagnóstico para quien compila —hablaba de `--dart-define`— colocado en la
  primera pantalla que ve un usuario, y se colaba en las capturas de la ficha de
  la tienda.
- La tarjeta del tour guiado **ya no puede salirse de la pantalla**. Con las
  explicaciones largas de algunos idiomas y una ilustración, desbordaba hasta
  488 px por abajo en un móvil de 360×640 y dejaba «Siguiente» y «Saltar el
  tour» fuera de la pantalla: el tour no se podía ni terminar ni saltar. Ahora
  el cuerpo se desplaza dentro de la tarjeta y los botones se quedan fijos.
- La documentación ya no se genera con **Pandoc y TeX Live**, sino con Python y
  un navegador sin ventana. La instalación en la CI baja de unos 800 MB a unos
  segundos, y el estilo de los documentos pasa a ser nuestro en lugar de la
  plantilla por defecto de LaTeX.
- **El motor de cálculo de saldos se ha reescrito con un índice por grupo.** En
  un grupo de quince personas con mil gastos, calcular los saldos pasa de 197 ms
  a 13,5 ms en frío y a menos de 0,1 ms cuando ya está calculado en el mismo
  fotograma. Los resultados son idénticos al céntimo.
- El realce de la imagen del ticket se ejecuta **en otra isla** y usa
  **binarización adaptativa de Sauvola** en lugar de un umbral global fijo. Ya
  no bloquea la interfaz y aguanta las sombras.
- El reconocimiento solo hace una segunda pasada sobre la imagen realzada
  **cuando la primera no convence**, en lugar de hacer siempre las dos.
- El repositorio de Firestore **reutiliza los modelos ya construidos** de los
  grupos que no han cambiado, en lugar de reconstruirlos todos en cada
  instantánea.
- Las escrituras de gastos y categorías envían **solo los campos que cambian**
  en lugar del documento entero.
- Las listas de miembros derivadas (`visibleMembers`, `activeMembers`,
  `selectableMembers`) se calculan una vez por instancia de grupo en lugar de en
  cada acceso.
- Todo el redondeo monetario usa aritmética en lugar de dar la vuelta por
  `toStringAsFixed`.
- `minSdk` sube a 26 y la versión de publicación activa minificación y recorte
  de recursos.

### Corregido

- **El color del texto sobre los botones no cumplía el contraste AA en ninguna
  de las trece paletas.** `colorOn` decidía con
  `ThemeData.estimateBrightnessForColor`, que va por un umbral de luminancia y
  no por relación de contraste, y ponía texto blanco sobre acentos claros: el
  naranja del tema por defecto daba 3,68:1 cuando AA exige 4,5:1. Ahora se
  calcula el contraste de verdad, y hay una prueba por paleta que lo comprueba.
- Los colores de texto de los contenedores y de los chips se calculaban sobre el
  color de acento a plena intensidad, no sobre el resultado de mezclarlo al 10 %
  o al 18 % con el fondo, que es lo que se ve en pantalla.
- **El proyecto recién clonado no compilaba.** El plugin de Gradle de Google
  Services aborta la compilación si no encuentra `google-services.json`, y ese
  fichero lleva credenciales y no se versiona. El código Dart sí contemplaba la
  ausencia de credenciales y arrancaba en modo de demostración, pero era
  imposible llegar hasta ahí: `flutter build apk` fallaba en
  `processDebugGoogleServices`. Ahora el plugin se aplica solo cuando el fichero
  existe, y sin él se compila y se avisa por consola.
- El parser de tickets **ya no se come el ticket entero** cuando la cabecera
  contiene la palabra «total». Antes cortaba en la primera aparición.
- El parser **ya no descarta productos legítimos** por contener una palabra
  clave como subcadena. «Gouda» contiene «ud», «Antipasto» contiene «tip» y
  «Privado» contiene «iva»; los tres se perdían.
- Las líneas de descuento con importe negativo (`3,00-`, típico de impresoras
  térmicas) ahora restan del reparto en lugar de descartarse.
- Fechas, horas y porcentajes ya no se confunden con importes.
- Los ficheros temporales del realce de imagen se borran después de usarse. Se
  acumulaban uno por cada ticket leído.
- La opción «Seguir el sistema» era imposible: se pasaba la misma paleta a
  `theme` y a `darkTheme` con `themeMode` fijo en claro.
- La pantalla de Ajustes leía la lista de grupos con `ref.read` sobre un
  proveedor `autoDispose`, que lo crea y lo destruye en el acto: la exportación
  de datos habría salido siempre sin ningún grupo.

## [1.0.0] — 2026-03-14

Primera etiqueta del proyecto, con un APK de la app antes de esta entrega. Se
mantiene por no romper a quien la tuviera fijada.
