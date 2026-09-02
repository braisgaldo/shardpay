---
title: "ShardPay — Eliminar tu cuenta"
lang: es
---

# Eliminar tu cuenta de ShardPay

**Última actualización: 2 de septiembre de 2026**

Aplicación: **ShardPay**, de **Ghato Studio** (Brais Castiñeiras Galdo).
Contacto: [ghatostudioofficial@gmail.com](mailto:ghatostudioofficial@gmail.com)

Esta página explica cómo pedir que se elimine tu cuenta de ShardPay y qué pasa
exactamente con cada dato cuando lo haces.

---

## Cómo eliminarla desde la app

Es la vía normal, y no hace falta pedir permiso a nadie: se ejecuta en el
momento.

1. Abre **ShardPay** en tu móvil.
2. Entra en tu cuenta, si no lo estabas ya.
3. Ve a la pestaña **Ajustes**, abajo a la derecha.
4. Baja hasta el final, a la zona **Cuenta**.
5. Pulsa **Eliminar perfil**.
6. Lee el aviso y confirma pulsando **Eliminar**.

La app te devuelve a la pantalla de acceso. Ya está hecho: no hay ningún correo
de confirmación que esperar ni ningún plazo que cumplir.

> **Antes de borrar, guarda lo tuyo si lo quieres.** En **Ajustes → Exportar mis
> datos** sale un fichero con todos tus grupos y gastos. Después de eliminar la
> cuenta ya no hay de dónde sacarlo.

> **Si eres la persona propietaria de un grupo con más gente**, la propiedad pasa
> automáticamente a otro miembro activo. Si eras la única persona del grupo, el
> grupo se elimina completo.

---

## Cómo eliminarla si no puedes entrar en la app

Si has perdido el acceso —contraseña olvidada, móvil perdido, la app no
arranca—, escribe a
[ghatostudioofficial@gmail.com](mailto:ghatostudioofficial@gmail.com) con:

- el asunto **«Eliminar mi cuenta de ShardPay»**, y
- **la dirección de correo con la que te registraste**.

Se te responde desde esa misma dirección para confirmar que la petición es tuya,
y la cuenta se elimina en cuanto respondas. El plazo máximo de respuesta es de
**30 días**, el que fija el Reglamento General de Protección de Datos, aunque en
la práctica es cuestión de días.

---

## Qué se elimina y qué se conserva

### Se elimina, de inmediato y por completo

| Dato | Dónde estaba |
| --- | --- |
| Tu nombre | Perfil y grupos |
| Tu dirección de correo | Perfil, credencial de acceso y grupos |
| Tu foto de perfil | Perfil y grupos |
| Tu credencial de acceso (contraseña o vínculo con Google) | Firebase Authentication |
| Tu documento de usuario y tus preferencias | Firestore |
| Tus notificaciones | Firestore |
| Los grupos en los que eras la única persona, con todos sus gastos | Firestore |

### Se conserva

Una sola cosa, y conviene entender por qué.

**Tu participación en los grupos compartidos**, es decir: los gastos que pagaste
o en los que participaste, junto con un identificador interno sin ningún dato
personal asociado.

La razón es que un gasto de grupo no es tuyo, es de todos. Si pagaste una cena
de cinco personas y esa línea desapareciera, las otras cuatro personas verían
saldos que no cuadran y deudas que se evaporan. Por eso tu participación queda
marcada como **cuenta eliminada** y **tu nombre, tu correo y tu foto se borran de
ella**: los demás miembros del grupo siguen viendo que hubo un gasto y cuánto
costaba, pero ya no ven quién eras.

Los importes, las fechas y las notas **de los gastos que creaste** siguen
visibles para los miembros de esos grupos, igual que antes. Si quieres que
también desaparezcan, **bórralos antes** —se pueden borrar uno a uno sin eliminar
la cuenta, como se explica más abajo— o pídelo en el correo de solicitud.

**Las fotos de tickets no aparecen en ninguna de las dos listas** porque no se
guardan en ningún sitio. La foto se usa para leer el ticket en tu propio móvil y
se descarta ahí mismo: no se sube a la nube ni queda asociada al gasto.

### Periodos de retención adicionales

- **No se guardan copias de seguridad propias.** La única copia de tus datos que
  existe fuera de la nube es la que tú mismo hayas exportado a un fichero.
- Los datos viven en **Google Cloud Firestore**. La eliminación es inmediata en
  la base de datos; las copias internas de la infraestructura de Google se
  purgan según el
  [proceso de eliminación de datos de Google Cloud](https://cloud.google.com/docs/security/deletion),
  que no está bajo mi control.
- **No hay ningún periodo de gracia ni de reactivación.** No se puede recuperar
  una cuenta eliminada: si vuelves, empiezas de cero.

---

## Borrar datos concretos sin eliminar la cuenta

No hace falta borrarlo todo para borrar algo. Desde la propia app, y sin pedir
permiso a nadie:

| Qué quieres borrar | Cómo |
| --- | --- |
| **Un gasto** —con su importe, su fecha y su nota— | Abre el grupo, pestaña **Gastos**, despliega el gasto y pulsa **Eliminar** |
| **Un grupo entero**, con todos sus gastos, para todo el mundo | Abre el grupo → menú **⋮** → **Eliminar grupo**. Solo puede hacerlo quien lo administra |
| **Tu participación en un grupo**, dejando el histórico del resto intacto | Abre el grupo → menú **⋮** → **Abandonar grupo** |
| **El nombre con el que te ven** en un grupo | Abre el grupo → **Ajustes del grupo** → **Alias de miembros** |

Todo eso se ejecuta en el momento y no se puede deshacer.

**Si prefieres pedirlo por escrito**, escribe a
[ghatostudioofficial@gmail.com](mailto:ghatostudioofficial@gmail.com) desde la
dirección con la que te registraste, diciendo qué quieres que se borre. El plazo
máximo de respuesta es de **30 días**.

Un aviso honesto sobre los gastos de grupo: un gasto compartido no es solo tuyo.
Si borras uno que pagaste, los saldos del resto del grupo cambian, porque esa
deuda deja de existir para todos. Es lo correcto —el dato es tuyo y puedes
borrarlo— pero conviene saberlo antes de hacerlo.

---

## Tus otros derechos

Además de la supresión, bajo el Reglamento General de Protección de Datos
(UE 2016/679) puedes ejercer el acceso, la portabilidad, la rectificación, la
oposición y la limitación. Cómo hacerlo, y todo el detalle de qué datos se
tratan y para qué, está en la
[política de privacidad](privacidad.html).

Si crees que algo no se ha hecho bien, puedes reclamar ante la
**Agencia Española de Protección de Datos** (<https://www.aepd.es>).
