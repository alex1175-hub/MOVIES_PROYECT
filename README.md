# PetStation (app Flutter para Android)

Se conecta por Bluetooth LE al ESP32 (nombre `PetStation`) y muestra/envía los mismos datos que los topics MQTT.

## Crear el proyecto
Requiere Flutter instalado (`flutter doctor`).

```
flutter create --org mx.ucol --platforms android petstation_app
```

Después, copia sobre el proyecto creado:
1. `pubspec.yaml`  -> reemplaza el de la raíz.
2. `lib/main.dart` y `lib/ble_service.dart` -> reemplazan/agregan en `lib/`.
3. Borra `test/widget_test.dart` (hace referencia a la app de ejemplo).
4. Abre `android/app/src/main/AndroidManifest.xml` y pega los permisos de `manifest_permisos.xml`.
5. En `android/app/build.gradle(.kts)` verifica que `minSdk` sea 21 o mayor.

```
cd petstation_app
flutter pub get
flutter run          # con el celular conectado por USB y depuración USB activada
flutter build apk    # para generar el APK
```

## Uso
1. Enciende el ESP32 (con el firmware con Bluetooth, `USAR_BLE 1`).
2. Abre la app, acepta los permisos y toca **Conectar** en `PetStation`.
3. Verás sensores, programas y eventos en vivo; los botones envían ON/OFF y el programa de comida/agua.
4. En "Eventos y comandos" puedes escribir líneas como `puerta ON` o `petstation/config/agua {"cantidad":150,"intervalo_min":240}`.

## Registro e inicio de sesión
La app pide usuario y contraseña al abrir. Se conecta a la API PHP (`petstation_api.zip`, se instala en XAMPP) que guarda los usuarios en MySQL.
1. Instala la API y ejecuta `sesiones.sql` (ver el README de la API).
2. En el manifest agrega el permiso `INTERNET` y `android:usesCleartextTraffic="true"` (ver `manifest_permisos.xml`).
3. En la pantalla de inicio abre **Servidor** y escribe la dirección de tu PC: `http://IP-DE-TU-PC/petstation_api` (en el emulador: `http://10.0.2.2/petstation_api`). El celular y la PC deben estar en la misma red.
4. Después de `flutter pub get`, la sesión se conserva hasta que toques **Cerrar sesión** (menú de la pantalla de búsqueda).
5. Conectado a una estación, el botón de enlace (arriba) la **vincula a tu cuenta**; también puedes agregarlas a mano en **Mis máquinas**.

## Configurar el WiFi de la estación
En la pantalla principal, tarjeta **WiFi de la estación** -> **Configurar WiFi** -> escribe red y contraseña. La estación prueba la red nueva 20 s; si no conecta, vuelve a la anterior. Se guarda en la memoria del ESP32 (sobrevive a reinicios).
Por seguridad se recomienda enviarla por Bluetooth (no por MQTT con un broker público).

## Configurar la estación (nombre, WiFi y base de datos)
En la tarjeta **WiFi de la estación** toca **Configurar WiFi** y escribe el nombre de la estación, la red, la contraseña y la dirección de la API (la IP de tu PC, no localhost). La app:
1. le pide al servidor que vincule la estación a tu cuenta (recibe una clave para la estación),
2. manda por Bluetooth a la estación: nombre, tu ID de usuario, la dirección de la API, la clave y el WiFi.
La estación se conecta al WiFi y empieza a enviar lecturas, eventos, raciones y su programa a la base de datos. La tarjeta muestra el estado en **Base de datos**.

## Protocolo
Servicio UART de Nordic (NUS): servicio `6E400001-...`, RX (app->ESP32) `6E400002-...`, TX (ESP32->app, notify) `6E400003-...`.
Una línea por mensaje: `<topic> <contenido>\n`.

No se puede probar en Wokwi (no simula Bluetooth): usa un ESP32 real.

## Calculadora de programas
Menú principal → "Calculadora de programas" (también el icono de calculadora en el panel Bluetooth y en el panel en línea).
Datos: perro o gato, tamaño de la raza (solo perros), edad en meses y peso en kg (opcional: kcal/kg del alimento).
Sugiere gramos por ración, raciones al día y recarga de agua. Desde un panel, "Usar este programa" lo envía a la estación.
Es una estimación general; no sustituye al veterinario.
