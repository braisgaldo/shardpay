# ShardPay

**Divide tickets, no amistades.**

App móvil para repartir gastos en grupo. Le haces una foto al ticket y ShardPay
reconoce las líneas, los importes y el total, comprueba que la suma cuadre con lo
que pone el papel, y calcula quién le debe qué a quién.

Gratis, sin anuncios y sin recoger datos para nada que no sea hacerla funcionar.

[![CI](https://github.com/braisgaldo/shardpay/actions/workflows/ci.yml/badge.svg)](https://github.com/braisgaldo/shardpay/actions/workflows/ci.yml)
[![Licencia](https://img.shields.io/badge/licencia-Apache--2.0-blue)](LICENSE)

---

## Qué hace

- **Lee tickets con la cámara.** Pantalla de captura propia con guía de
  encuadre, linterna y enfoque al tocar. El reconocimiento de texto ocurre
  **entero en el dispositivo**: las fotos no salen del móvil.
- **Cuadra con el total impreso.** Si la suma de las líneas no llega al total,
  añade una línea de ajuste y lo dice. El grupo reparte lo que de verdad se pagó,
  no una cifra aproximada.
- **Reparte línea a línea.** A partes iguales de un toque, o con el porcentaje
  exacto de cada persona en cada línea.
- **Salda con el mínimo de pagos.** Si tres personas se deben cosas cruzadas,
  propone las dos transferencias que hacen falta, no las seis.
- **Grupos compartidos** con invitación por enlace o QR, incluso para gente que
  todavía no tiene cuenta.
- **Exporta e importa** todos tus datos en un fichero `.shardpay.bak`.
- **14 idiomas y 13 temas**, con soporte de derecha a izquierda para el árabe y
  la opción de seguir el modo claro u oscuro del sistema.

> **Seguridad.** Un grupo lo leen sus miembros y nadie más. Las reglas de
> Firestore que lo garantizan se ejecutan contra el emulador en cada envío —38
> comprobaciones en `firestore-tests/`—, porque un agujero de este tipo no se ve
> leyendo el fichero. La historia de por qué esto no era así y cómo se arregló
> está en [ADR-0009](docs/adr/0009-lectura-de-invitaciones.md).

## Instalar

| Vía | Estado |
| --- | --- |
| [GitHub Releases](https://github.com/braisgaldo/shardpay/releases) — APK directo | disponible en cada versión |
| Google Play | pendiente de publicación |
| F-Droid | candidato |
| App Store | pendiente ([ADR-0007](docs/adr/0007-escritorio-e-ios.md)) |

El APK de las Releases se instala directamente, sin pasar por ninguna tienda.

## Desarrollar

```bash
git clone https://github.com/braisgaldo/shardpay.git
cd shardpay
flutter pub get
flutter run
```

**Arranca sin ninguna credencial.** Si no encuentra la configuración de Firebase,
usa un repositorio en memoria con datos de ejemplo y la app es completamente
navegable. Es el modo cómodo para tocar la interfaz y probar el lector de
tickets.

Para conectar con Firebase de verdad, y para todo lo demás, mira
[`docs/INSTALL.md`](docs/INSTALL.md).

### Probar

```bash
flutter test        # 220 pruebas, sin dispositivo, en unos 16 segundos
```

Entre ellas hay una comprobación de **contraste AA para las trece paletas** y
otra que verifica que `locales_config.xml` no se separe de la lista de idiomas de
Dart.

El núcleo de lógica (`lib/core/`) es **Dart puro sin Flutter ni plugins**, así que
también se puede probar sin el SDK de Flutter:

```bash
dart test test/core
```

## Cómo está montado

```
lib/
├── core/           DART PURO — parser de tickets, saldos, copias, políticas
├── models/         modelo de dominio
├── repositories/   Firestore + repositorio de demostración
├── services/       cámara, OCR, ficheros, notificaciones
├── screens/        pantallas
└── widgets/        piezas reutilizables
```

La regla que lo sostiene: **`lib/core/` no importa Flutter, ni `dart:ui`, ni
ningún plugin.** Es lo que permite probar la lógica en milisegundos y sin
dispositivo, y lo único que habría que traducir si algún día se migra a otra
tecnología.

El mapa completo está en [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Documentación

| Documento | Para quién |
| --- | --- |
| [Manual de usuario](docs/MANUAL-USUARIO.md) | quien usa la app |
| [Manual técnico](docs/MANUAL-TECNICO.md) | quien la toca |
| [Arquitectura](docs/ARCHITECTURE.md) | quien quiere entenderla |
| [Instalación y despliegue](docs/INSTALL.md) | quien la compila |
| [Guía de publicación](docs/GUIA-PUBLICACION.md) | quien la sube a las tiendas |
| [Política de privacidad](docs/PRIVACIDAD.md) | todo el mundo |
| [Decisiones de arquitectura](docs/adr/) | quien se pregunta «¿y por qué así?» |

Los manuales en **HTML y PDF** —con portada, índice, estilo propio y, en el de
usuario, **capturas de la app incrustadas**— se generan con
[`docs/build-docs.sh`](docs/build-docs.sh) (Python y un navegador sin ventana,
sin Pandoc) y se adjuntan a cada
[Release](https://github.com/braisgaldo/shardpay/releases). Cada uno sale como un
único fichero, sin carpeta de imágenes al lado. No se versionan: la fuente es el
Markdown de `docs/`.

## Privacidad, en corto

- El texto de los tickets se reconoce **en tu móvil**, con ML Kit. Las fotos no
  se envían a ningún servicio de terceros.
- Los datos de un grupo los ven **los miembros de ese grupo**.
- **No hay analítica, ni telemetría, ni publicidad.**
- Solo dos permisos: cámara y notificaciones, los dos opcionales y justificados
  en [ADR-0006](docs/adr/0006-permisos-y-privacidad.md).

Política completa: <https://braisgaldo.github.io/shardpay/privacidad.html>

## Invítame a un café

ShardPay es **gratuita y completa**. No hay versión de pago, no hay funciones
reservadas y no las va a haber.

Si te resulta útil, puedes [invitarme a un café](https://revolut.me/brais2oz6).
**No desbloquea absolutamente nada**: ni funciones, ni temas, ni contenido. Es un
agradecimiento por algo que ya tienes entero.

Por eso mismo el proyecto **no incluye ninguna biblioteca de facturación** de
ninguna tienda, y hay una comprobación en integración continua que falla si
alguna se cuela. El razonamiento completo, con las políticas de Google y de
Apple citadas, está en
[ADR-0008](docs/adr/0008-donacion-y-politicas-de-tienda.md).

## Contribuir

Las normas están en [`CONTRIBUTING.md`](CONTRIBUTING.md). En resumen: commits en
castellano, todo lo que entre en `lib/core/` con pruebas, y nada de texto fijo en
la interfaz.

Para fallos de seguridad, [`SECURITY.md`](SECURITY.md) — **no** una incidencia
pública.

Contacto: [ghatostudioofficial@gmail.com](mailto:ghatostudioofficial@gmail.com)

## Licencia

[Apache-2.0](LICENSE). Se eligió por dos motivos: incluye concesión expresa de
patentes, y es compatible con la distribución en la App Store, cosa que la GPL-3
no es.
