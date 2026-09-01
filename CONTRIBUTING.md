# Cómo contribuir a ShardPay

Gracias por pasarte. Esto es un proyecto personal, así que las normas son pocas
y concretas.

## Antes de escribir código

- Si es un fallo, abre una incidencia con la versión (la tienes en
  **Ajustes → Acerca de**), qué esperabas y qué pasó. Si es un problema de
  lectura de tickets, adjunta el ticket si puedes: es lo que más ayuda.
- Si es una funcionalidad nueva, coméntala primero. Puede que ya esté decidido
  que no entra, y así no pierdes el rato.

## Ramas y commits

- `main` es estable. Todo lo demás va en `feat/…`, `fix/…`, `docs/…` o
  `chore/…`, y entra por *pull request*.
- **Los commits van en castellano**, en formato *conventional commits*:

  ```
  feat(tickets): cuadrar la lectura contra el total impreso

  El OCR se deja lineas cuando el ticket esta arrugado, y el grupo acababa
  repartiendo una cifra que no era la del ticket. Ahora, si la suma no llega
  al total, se anade una linea de ajuste y se avisa.
  ```

  El cuerpo explica **por qué**, no qué líneas cambiaron: eso ya lo cuenta el
  diff.
- Sin *trailers* de coautoría.
- Historia limpia: aplasta los commits de «arreglar typo» antes de pedir la
  fusión.

## Calidad

Antes de abrir la *pull request*:

```bash
flutter analyze          # sin avisos
flutter test             # todo en verde
dart format --line-length 140 lib test
```

La integración continua ejecuta lo mismo, más la comprobación de que no se ha
colado ninguna biblioteca de facturación.

### Dónde poner cada cosa

- `lib/core/` — **Dart puro**, sin Flutter y sin plugins. Todo lo que se pueda
  probar sin dispositivo vive aquí: el parser de tickets, el cálculo de saldos,
  el formato de copia de seguridad y la política del aviso de donación. Si una
  regla de negocio se te va a `lib/screens`, está mal puesta.
- `lib/models/` — modelos de dominio y su serialización.
- `lib/repositories/` — acceso a datos, con la implementación de Firebase y la
  de demostración local.
- `lib/services/` — lo que necesita el dispositivo: cámara, OCR, ficheros,
  notificaciones.
- `lib/screens/` y `lib/widgets/` — interfaz. Sin lógica de negocio.

**Todo lo que entre en `lib/core/` necesita pruebas.** Es barato, corre en
milisegundos y es lo que permite tocar el parser sin miedo.

## Cadenas de texto

Nada de texto fijo en la interfaz: todo pasa por `tr()` en
`lib/app/app_text.dart`, con el castellano obligatorio. Si añades un idioma,
añádelo también a `appLanguageOptions`, a `locales_config.xml` y a
`resourceConfigurations` en `android/app/build.gradle.kts`.

Los mensajes que genera el núcleo (avisos del parser, errores de copia de
seguridad) se devuelven como **enum**, nunca como texto: los traduce la capa de
interfaz.

## Lo que no entra

- Ninguna biblioteca de facturación, ni de Google Play ni de Apple.
- Nada que ate una función, un tema o cualquier contenido a haber donado.
- Analítica o telemetría sin consentimiento explícito.
- Permisos que no estén justificados en un ADR y en la ficha de tienda.
- Secretos en el repositorio. Ni claves, ni tokens, ni almacenes de claves.
