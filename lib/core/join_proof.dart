/// Prueba de que quien se une a un grupo conoce su PIN.
///
/// Hasta ADR-0009 el PIN se comprobaba en el movil: la app leia el grupo entero
/// —incluido `joinPin`— y comparaba. Eso solo funcionaba porque las reglas
/// dejaban leer cualquier grupo a cualquiera con cuenta, que era precisamente el
/// agujero. Y una comprobacion que hace el cliente con datos que el cliente
/// controla no comprueba nada.
///
/// Ahora el movil no puede leer el grupo antes de entrar. Manda esta prueba en
/// el campo `joinProof` y las reglas de Firestore la recalculan con el PIN de
/// verdad, que solo el servidor puede leer:
///
/// ```
/// request.resource.data.joinProof ==
///   hashing.sha256(resource.data.joinPin + ':' + request.auth.uid).toHexString()
/// ```
///
/// El uid va dentro del hash a proposito: si no, la prueba de una persona
/// serviria para que entrara cualquier otra que la hubiera visto pasar.
///
/// Esto **no** convierte el PIN en un secreto fuerte: son cuatro digitos y quien
/// pueda escribir contra el grupo puede probarlos todos. Es una barrera contra
/// el que se encuentra un enlace, no contra un atacante decidido; lo que impide
/// leer el grupo es la regla de pertenencia, no esto.
library;

import 'dart:convert' show utf8;

import 'package:crypto/crypto.dart';

/// Calcula la prueba que espera `firestore.rules` para `joinProof`.
///
/// El formato exacto —`"<pin>:<uid>"`, SHA-256, **hex en mayusculas**— esta
/// fijado por `test/core/join_proof_test.dart` y por las pruebas de reglas de
/// `firestore-tests/`. Cambiarlo aqui sin cambiarlo alli deja a la gente sin
/// poder entrar en ningun grupo.
///
/// ## Por que hex y no base64
///
/// Esto era base64 y estaba roto en produccion: `toBase64()` de las reglas de
/// Firestore devuelve base64 **urlsafe** —con `-` y `_`—, mientras que
/// `base64.encode` de Dart devuelve el estandar, con `+` y `/`. Los dos
/// coinciden solo cuando el hash no contiene ninguno de esos dos caracteres, y
/// eso pasa en una de cada cuatro veces: **tres de cada cuatro personas no
/// podian entrar en un grupo**, con un «permiso denegado» que no explicaba nada.
///
/// Y no se detecto porque el valor fijado en la prueba era el de `uid-bea`, que
/// da la casualidad de ser uno de los que no lleva `+` ni `/`.
///
/// Hex no tiene variantes de alfabeto. Solo tiene mayusculas y minusculas, y eso
/// se ve a simple vista. `toHexString()` de las reglas devuelve mayusculas.
String joinProofFor({required String joinPin, required String userId}) {
  final payload = utf8.encode('${joinPin.trim()}:${userId.trim()}');
  return sha256.convert(payload).toString().toUpperCase();
}
