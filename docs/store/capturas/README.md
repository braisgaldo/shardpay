# Capturas de la ficha de la tienda

Hechas sobre un **Samsung Galaxy S22 Ultra** (1080 × 2316), con la app compilada
en **modo de publicación** y en modo de demostración local (sin credenciales de
Firebase), así que los datos que se ven son de ejemplo y no de nadie.

Se generan con [`scripts/capturas.sh`](../../../scripts/capturas.sh).

## Reglas que hay que respetar al rehacerlas

Las tres salieron de haberlo hecho mal antes:

1. **Nada de notificaciones en la barra de estado.** Las primeras capturas
   llevaban los iconos de WhatsApp, Gmail y Teams del móvil de quien las hizo.
   `barra_limpia` activa el modo de demostración de SystemUI y los quita.
2. **Nada de avisos emergentes.** El modo de demostración quita los iconos pero
   no impide que salte un aviso flotante encima de la captura; llegó a colarse un
   mensaje de Teams con el nombre de una persona real. `barra_limpia` activa
   además el modo «no molestar», y `barra_normal` lo devuelve.
3. **Compilación de publicación, no de depuración.** La compilación de
   depuración enseña el aviso de «modo demo local porque faltan credenciales
   Firebase en --dart-define», que salía en la captura de la pantalla de acceso.

4. **Nada de marco verde de grabación.** Cuando Android graba o proyecta la
   pantalla pinta un marco verde de tres a cinco píxeles alrededor de todo. Once
   capturas lo tenían y no se vio hasta maquetarlas en el manual. Se comprueba
   con:

   ```bash
   python scripts/limpiar_capturas.py              # avisa
   python scripts/limpiar_capturas.py --arreglar   # recorta
   ```

   La CI ejecuta la primera forma y falla si encuentra alguna.

Lo que **no** se consigue en este móvil: Samsung ignora los comandos de reloj y
de iconos de estado del modo de demostración, así que la hora es la real y
quedan los iconos propios del fabricante (silencio, protección de batería). No
son notificaciones y no revelan nada.

## Qué cubre cada una

| Fichero | Qué enseña |
| --- | --- |
| `01-acceso` | Pantalla de acceso, tema oscuro |
| `02-acceso-relleno` | La misma con los campos rellenos |
| `03-tour-01-bienvenida`, `03-tour-02` … `03-tour-11` | El tour guiado entero, once pasos. Los pasos 5 a 8 cambian de pestaña solos y el foco recorta el elemento del que hablan |
| `04-grupos` | Lista de grupos |
| `05-grupo-detalle` | Ficha de grupo desplegada: gasto, balance propio y miembros, incluidos los pendientes |
| `06-grupo-gastos` | Gastos del grupo |
| `07-balance-global` | Saldo global entre todos los grupos |
| `08-estadisticas` | Estadísticas: selector de vista y filtro de grupos |
| `08b-estadisticas-grafica` | Insights: mayor categoría, grupo más activo, quién adelanta más |
| `08c-estadisticas-categorias` | Distribución por categoría |
| `09-ajustes` | Ajustes con las seis secciones plegadas y su resumen |
| `10-ajustes-tema` | Sección de tema: modo claro/oscuro/sistema y paleta |
| `11-ajustes-idioma` | Sección de idioma |
| `12-ajustes-shardpay` | Sección ShardPay: tour, ayuda y los dos botones grandes de compartir e invitar a un café |
| `12b-ajustes-shardpay-claro` | Los mismos botones en tema claro, donde el texto del botón con contorno tiene que ser oscuro |
| `13-ayuda` | Pantalla de ayuda |
| `14-ayuda-ejemplo` | El ejemplo completo: las cinco deudas directas y los dos pagos que las liquidan |
| `15-apoyar` | Panel de donación. No desbloquea nada |
| `16-acerca-de` | Versión, compilación, licencia y contacto |
| `17-tema-claro` | Cambio a tema claro |
| `18-grupos-claro` | Lista de grupos en tema claro |
| `19-selector-paletas` | Las trece paletas como lista |
| `20-ajustes-claro` | Ajustes en tema claro |
| `21-selector-idiomas` | Los catorce idiomas, cada uno en su propio idioma |
| `22-arabe-ajustes` | Árabe: interfaz espejada de derecha a izquierda |
| `23-arabe-grupos` | Lista de grupos en árabe |
| `24-arabe-notificaciones` | Sección de notificaciones en árabe |
| `25-arabe-selector-idiomas` | El selector de idiomas, también espejado |
| `26-grupo-pantalla` | Pantalla de un grupo: pestañas y acciones rápidas |
| `27-grupo-gastos` | Pestaña de gastos del grupo |
| `28-grupo-deudas` | Pestaña de deudas: quién recibe y quién debe |
| `29-grupo-estadisticas` | Pestaña de estadísticas del grupo |
| `30-anadir-gasto` | Añadir un gasto, con subgastos opcionales |
| `31-lector-tickets` | Lector de tickets: marco de encuadre, linterna y aviso de encuadre. La vista sale oscura porque el móvil estaba apoyado boca abajo |

## Pendiente


- **Ninguna captura enseña un ticket real leído por la cámara.** El lector se ve,
  pero no hay una captura del diálogo de revisión con las líneas ya
  reconocidas. Hace falta un ticket de papel delante.
- La vista previa del lector (`31-lector-tickets`) sale en negro porque el móvil
  estaba apoyado. Se puede repetir apuntando a algo.

## Las que van a Google Play

Ocho de estas capturas se montan además para la ficha de la tienda, en
`docs/google_play/capturas/`. **No sirven tal cual**: Play exige una relación de
aspecto entre 16:9 y 9:16, y estas son 1080×2316, o sea 1:2,14. Se rechazarían.

`scripts/graficos_play.py` las monta centradas sobre un lienzo de 1242×2208
—9:16 exacto— con el fondo de la marca, sin barras del sistema y con las esquinas
redondeadas. Los originales de esta carpeta no se tocan.

## Ajustes del móvil que toca la sesión, y que se devuelven al terminar

`barra_limpia` cambia tres cosas y `barra_normal` las devuelve: el modo de
demostración de SystemUI, el modo «no molestar» y nada más. La sesión sube además
el tiempo de apagado de pantalla para que el móvil no se bloquee a mitad, y hay
que devolverlo a mano:

```bash
adb shell settings put system screen_off_timeout 30000
```

Capturar el lector de tickets exige el permiso de cámara. Si se concede con
`adb shell pm grant`, la app queda con el permiso puesto, que es lo normal para
una app instalada de verdad.

## Dónde se usan

Además de la ficha de la tienda, veinte de estas capturas van **dentro del manual
de usuario** en HTML y PDF. `docs/build_docs.py` les recorta las barras del
sistema, las reescala y las incrusta en el documento, así que el manual generado
es un fichero suelto. Los originales de esta carpeta no se tocan.
