# Ficha de la App Store

Equivalencias con la ficha de Google Play y lo que Apple pide y Google no.

Los textos de descripción son los mismos que en
[`ficha-play.md`](ficha-play.md); aquí solo está lo que cambia.

> **Estado:** pendiente. Publicar en la App Store requiere el Apple Developer
> Program (99 €/año) y un Mac. Véase
> [ADR-0007](../adr/0007-escritorio-e-ios.md).

## Campos que cambian

| Google Play | App Store Connect | Límite | Contenido |
| --- | --- | ---: | --- |
| Descripción corta | **Subtítulo** | 30 | Ver tabla de abajo |
| Descripción larga | Descripción | 4000 | Igual que en Play |
| — | **Texto promocional** | 170 | Ver tabla de abajo |
| — | **Palabras clave** | 100 | Ver tabla de abajo |
| Gráfico destacado | No existe | — | — |
| Clasificación IARC | Age Rating de Apple | — | 4+ |

## Subtítulo (30 caracteres)

| Idioma | Subtítulo | Longitud |
| --- | --- | ---: |
| Castellano | Gastos en grupo sin líos | 24 |
| Inglés | Group expenses, sorted | 22 |
| Gallego | Gastos en grupo sen líos | 24 |
| Catalán | Despeses en grup sense embuts | 29 |
| Euskera | Taldeko gastuak, argi | 21 |
| Francés | Dépenses de groupe, réglées | 27 |
| Italiano | Spese di gruppo, chiare | 23 |
| Portugués | Despesas em grupo sem líos | 26 |
| Alemán | Gruppenausgaben, geklärt | 24 |
| Griego | Ομαδικά έξοδα, ξεκάθαρα | 23 |
| Ruso | Общие расходы без споров | 24 |
| Árabe | مصاريف المجموعة بلا تعقيد | 25 |
| Chino | 群组分账，清清楚楚 | 9 |
| Japonés | グループの割り勘をすっきり | 13 |

## Palabras clave (100 caracteres, separadas por comas, sin espacios)

```
gastos,grupo,ticket,recibo,dividir,cuentas,amigos,viaje,piso,deudas,saldo,ocr,escanear
```

Consejos que Apple da y que conviene respetar: no repetir palabras que ya están
en el título o el subtítulo, no usar nombres de la competencia, y no usar
plurales cuando el singular ya indexa.

## Texto promocional (170 caracteres)

Se puede cambiar sin enviar una versión nueva a revisión, así que sirve para
anunciar novedades.

> Nuevo: pantalla de captura propia con guía de encuadre y linterna, y
> comprobación de que la suma de las líneas cuadra con el total impreso del
> ticket.

## Textos de permisos (`Info.plist`)

Apple rechaza las apps cuyos textos de permiso no expliquen el uso concreto. Van
localizados en `InfoPlist.strings` por idioma.

### `NSCameraUsageDescription`

| Idioma | Texto |
| --- | --- |
| Castellano | ShardPay usa la cámara para fotografiar tus tickets. El texto se reconoce en tu propio dispositivo y la foto no se envía a ningún servicio externo. |
| Inglés | ShardPay uses the camera to photograph your receipts. The text is recognised on your own device and the photo is never sent to any external service. |
| Gallego | ShardPay usa a cámara para fotografar os teus tickets. O texto recoñécese no teu propio dispositivo e a foto non se envía a ningún servizo externo. |
| Catalán | ShardPay fa servir la càmera per fotografiar els teus tiquets. El text es reconeix al teu propi dispositiu i la foto no s'envia a cap servei extern. |
| Euskera | ShardPay-k kamera erabiltzen du zure tiketak argazkitzeko. Testua zure gailuan bertan ezagutzen da eta argazkia ez da kanpoko zerbitzu batera bidaltzen. |
| Francés | ShardPay utilise l'appareil photo pour photographier vos tickets. Le texte est reconnu sur votre appareil et la photo n'est envoyée à aucun service externe. |
| Italiano | ShardPay usa la fotocamera per fotografare i tuoi scontrini. Il testo viene riconosciuto sul tuo dispositivo e la foto non viene inviata ad alcun servizio esterno. |
| Portugués | O ShardPay usa a câmara para fotografar as tuas faturas. O texto é reconhecido no teu próprio dispositivo e a foto não é enviada para nenhum serviço externo. |
| Alemán | ShardPay nutzt die Kamera, um deine Belege zu fotografieren. Der Text wird auf deinem Gerät erkannt und das Foto wird an keinen externen Dienst gesendet. |
| Griego | Το ShardPay χρησιμοποιεί την κάμερα για να φωτογραφίζει τις αποδείξεις σου. Το κείμενο αναγνωρίζεται στη συσκευή σου και η φωτογραφία δεν στέλνεται πουθενά. |
| Ruso | ShardPay использует камеру для съёмки чеков. Текст распознаётся на вашем устройстве, и фотография не отправляется ни в какой внешний сервис. |
| Árabe | يستخدم ShardPay الكاميرا لتصوير إيصالاتك. يتم التعرف على النص على جهازك ولا تُرسل الصورة إلى أي خدمة خارجية. |
| Chino | ShardPay 使用相机拍摄你的小票。文字在你的设备上识别，照片不会发送到任何外部服务。 |
| Japonés | ShardPay はレシートの撮影にカメラを使用します。テキストは端末内で認識され、写真が外部サービスに送信されることはありません。 |

### `NSPhotoLibraryUsageDescription`

| Idioma | Texto |
| --- | --- |
| Castellano | ShardPay accede a tus fotos solo para que puedas elegir la imagen de un ticket que ya tengas guardada. |
| Inglés | ShardPay accesses your photos only so you can pick an image of a receipt you already have saved. |
| Gallego | ShardPay accede ás túas fotos só para que poidas escoller a imaxe dun ticket que xa teñas gardada. |
| Catalán | ShardPay accedeix a les teves fotos només perquè puguis triar la imatge d'un tiquet que ja tinguis desada. |
| Euskera | ShardPay-k zure argazkietara sartzen da soilik jada gordeta duzun tiket baten irudia aukeratu ahal izateko. |
| Francés | ShardPay accède à vos photos uniquement pour que vous puissiez choisir l'image d'un ticket déjà enregistré. |
| Italiano | ShardPay accede alle tue foto solo per permetterti di scegliere l'immagine di uno scontrino che hai già salvato. |
| Portugués | O ShardPay acede às tuas fotos apenas para que possas escolher a imagem de uma fatura que já tenhas guardada. |
| Alemán | ShardPay greift nur auf deine Fotos zu, damit du das Bild eines bereits gespeicherten Belegs auswählen kannst. |
| Griego | Το ShardPay έχει πρόσβαση στις φωτογραφίες σου μόνο για να μπορείς να διαλέξεις την εικόνα μιας απόδειξης που έχεις ήδη αποθηκεύσει. |
| Ruso | ShardPay обращается к вашим фотографиям только для того, чтобы вы могли выбрать изображение уже сохранённого чека. |
| Árabe | يصل ShardPay إلى صورك فقط لتتمكن من اختيار صورة إيصال محفوظة لديك بالفعل. |
| Chino | ShardPay 访问你的照片仅用于让你选择已保存的小票图片。 |
| Japonés | ShardPay が写真にアクセスするのは、保存済みのレシート画像を選べるようにするためだけです。 |

## Tipo de documento `.shardpay.bak`

Para que iOS ofrezca abrir una copia con ShardPay hay que declararla en
`Info.plist`:

```xml
<key>CFBundleDocumentTypes</key>
<array>
  <dict>
    <key>CFBundleTypeName</key>
    <string>Copia de ShardPay</string>
    <key>LSHandlerRank</key>
    <string>Owner</string>
    <key>LSItemContentTypes</key>
    <array>
      <string>es.ghatostudio.shardpay.backup</string>
    </array>
  </dict>
</array>

<key>UTExportedTypeDeclarations</key>
<array>
  <dict>
    <key>UTTypeIdentifier</key>
    <string>es.ghatostudio.shardpay.backup</string>
    <key>UTTypeDescription</key>
    <string>Copia de ShardPay</string>
    <key>UTTypeConformsTo</key>
    <array>
      <string>public.data</string>
    </array>
    <key>UTTypeTagSpecification</key>
    <dict>
      <key>public.filename-extension</key>
      <array>
        <string>bak</string>
      </array>
      <key>public.mime-type</key>
      <array>
        <string>application/vnd.ghatostudio.shardpay.backup</string>
      </array>
    </dict>
  </dict>
</array>
```

## App Privacy

Las respuestas son las mismas que en el formulario de Seguridad de los datos de
Google Play. Están en
[`../GUIA-PUBLICACION.md`](../GUIA-PUBLICACION.md#seguridad-de-los-datos).

Resumen para el «Nutrition Label»:

- **Datos vinculados a ti:** nombre, correo, identificadores (token de
  notificaciones), contenido del usuario (gastos y grupos).
- **Datos no vinculados a ti:** ninguno.
- **Datos usados para seguirte:** **ninguno**.

## Donación

**Apagada por defecto en iOS.** El motivo, con las directrices 3.1.1 y 3.2.1
citadas literalmente, está en
[ADR-0008](../adr/0008-donacion-y-politicas-de-tienda.md).

Si se decide enviarla activada, hay que compilar con
`--dart-define=SHARDPAY_DONATIONS_IOS=true` y estar preparado para un rechazo. En
ese caso, la respuesta a App Review es que la app es gratuita y completa, que no
se adquiere ningún bien digital ni ninguna funcionalidad, y que el enlace apunta
a la página del proyecto y no a una pasarela de pago.

## Capturas

Apple pide capturas por tamaño de pantalla, no por dispositivo:

| Tamaño | Resolución | ¿Obligatorio? |
| --- | --- | --- |
| iPhone 6,9" | 1320 × 2868 | Sí |
| iPhone 6,5" | 1242 × 2688 | Sí |
| iPad Pro 13" | 2064 × 2752 | Solo si se declara compatible con iPad |

Se guardan en `capturas/ios/`.
