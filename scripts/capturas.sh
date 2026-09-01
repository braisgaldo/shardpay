#!/usr/bin/env bash
#
# Utilidades para hacer las capturas de la ficha de la tienda.
#
# Dos cosas que se hicieron mal la primera vez y que este script evita:
#
# 1. **La barra de estado enseñaba las notificaciones reales del móvil.** En una
#    captura publicada eso son datos personales de quien la hizo. El modo de
#    demostración de SystemUI las quita.
# 2. **Se capturó una compilación de depuración**, que muestra el aviso de «modo
#    demo local porque faltan credenciales Firebase». Hay que capturar la
#    compilación de publicación, que es la que se instala la gente.
#
# Uso:
#   source scripts/capturas.sh
#   barra_limpia          # silencia avisos y limpia la barra
#   captura 01-arranque
#   ...
#   barra_normal
#
# Requiere `adb` en el PATH y un dispositivo desbloqueado.

: "${ADB:=adb}"
: "${SALIDA:=docs/store/capturas}"
: "${PAQUETE:=com.ghatostudio.shardpay}"

# Silencia los avisos emergentes mientras dura la sesión.
#
# El modo de demostración de SystemUI quita los iconos de la barra, pero **no**
# impide que salte un aviso flotante en mitad de una captura. Pasó: un mensaje de
# Teams con el nombre de una persona real encima de la pantalla de acceso. En un
# móvil personal esto no es opcional.
#
# Guarda el modo anterior en /tmp para poder devolverlo tal cual.
silencio_temporal() {
  "$ADB" shell settings get global zen_mode > "${TMPDIR:-/tmp}/shardpay_zen" 2>/dev/null || true
  # `priority` deja pasar las llamadas, y una llamada entrante de Teams con el
  # nombre de quien llama se colo encima de una captura. Silencio total.
  "$ADB" shell cmd notification set_dnd none >/dev/null 2>&1 || true
}

# Devuelve las notificaciones. Ejecutarlo SIEMPRE al terminar.
silencio_normal() {
  "$ADB" shell cmd notification set_dnd off >/dev/null 2>&1 || true
}

# Quita los iconos de notificación de la barra de estado.
#
# Samsung ignora los comandos `clock` y `status`, así que la hora sigue siendo la
# real y pueden quedar iconos propios del fabricante (silencio, protección de
# batería). No son notificaciones y no revelan nada: lo que importa es que no
# salga con quién estás hablando por WhatsApp.
barra_limpia() {
  silencio_temporal
  "$ADB" shell settings put global sysui_demo_allowed 1
  "$ADB" shell am broadcast -a com.android.systemui.demo -e command enter >/dev/null
  "$ADB" shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false >/dev/null
  "$ADB" shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 >/dev/null
  "$ADB" shell am broadcast -a com.android.systemui.demo -e command network -e mobile show -e level 4 -e datatype false >/dev/null
  "$ADB" shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false >/dev/null
}

# Devuelve la barra de estado a su comportamiento normal. Ejecutarlo SIEMPRE al
# terminar: dejar el móvil de otra persona en modo demostración es una faena.
barra_normal() {
  silencio_normal
  "$ADB" shell am broadcast -a com.android.systemui.demo -e command exit >/dev/null
  "$ADB" shell settings put global sysui_demo_allowed 0
}

# captura <nombre> [espera]
captura() {
  local nombre="$1"
  local espera="${2:-0.6}"
  sleep "$espera"
  "$ADB" shell "screencap -p /sdcard/_captura.png"
  "$ADB" pull /sdcard/_captura.png "$SALIDA/$nombre.png" >/dev/null
  "$ADB" shell "rm -f /sdcard/_captura.png"
  echo "  $nombre"
}

toca()    { "$ADB" shell input tap "$1" "$2"; sleep "${3:-0.7}"; }
desliza() { "$ADB" shell input swipe "$1" "$2" "$3" "$4" "${5:-300}"; sleep 0.6; }
atras()   { "$ADB" shell input keyevent KEYCODE_BACK; sleep "${1:-0.7}"; }
texto()   { "$ADB" shell input text "$1"; sleep 0.4; }

arranca_limpio() {
  "$ADB" shell pm clear "$PAQUETE" >/dev/null
  "$ADB" shell monkey -p "$PAQUETE" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  sleep 4
}
