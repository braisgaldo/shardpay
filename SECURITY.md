# Política de seguridad

## Versiones con soporte

Solo la última versión publicada. ShardPay es un proyecto personal y no hay
mantenimiento de ramas antiguas.

| Versión | Soporte |
| ------- | ------- |
| 1.0.x   | Sí      |
| < 1.0   | No      |

## Cómo avisar de un fallo de seguridad

**No abras una incidencia pública.** Escribe a
[ghatostudioofficial@gmail.com](mailto:ghatostudioofficial@gmail.com) con:

- Qué has encontrado y qué impacto tiene.
- Cómo reproducirlo.
- La versión afectada (está en **Ajustes → Acerca de**).

Respondo en un plazo de 7 días naturales. Si el fallo es real, acordamos una
fecha de publicación antes de contarlo en público.

## Qué se considera fallo de seguridad

- Acceso a datos de un grupo del que no eres miembro.
- Elevación de privilegios dentro de un grupo (pasar a administrador sin serlo).
- Cualquier forma de saltarse las reglas de Firestore de `firestore.rules`.
- Fuga de datos personales a un tercero.
- Ejecución de código a partir de una copia de seguridad manipulada.

## Qué no

- Que un miembro del grupo vea los gastos del grupo. Es lo que hace la app.
- Que una copia `.shardpay.bak` se pueda leer con un editor de texto: es un
  fichero del usuario, en su dispositivo, y está documentado que no va cifrado.
  La suma de verificación detecta corrupción, no protege contra nadie.
- Informes automáticos de escáneres sin un caso reproducible detrás.

## Secretos y credenciales

En este repositorio no hay ninguna credencial, y no debe haberla nunca:

- La configuración de Firebase se pasa por `--dart-define` o desde
  `config/firebase.local.json`, que está en `.gitignore`.
- El almacén de claves de firma vive en `android/key.properties` y en el fichero
  `.jks`, ambos ignorados por git.
- En integración continua, todo eso son *secrets* de GitHub Actions.

El procedimiento para regenerarlos está en
[docs/INSTALL.md](docs/INSTALL.md#regenerar-credenciales).

Si crees que se ha colado un secreto en la historia de git, avísame por correo
antes que nada: hay que rotarlo y reescribir la historia, en ese orden.
