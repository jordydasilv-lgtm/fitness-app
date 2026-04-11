# Checklist Final Para Subir NutrifynGo a Play Store

## 1. Firma de release

- Crea tu keystore de produccion.
- Guarda el archivo como `android/upload-keystore.jks`.
- Completa los valores reales en `android/key.properties`.
- Verifica que `android/key.properties` no se suba al repositorio.

### Comando sugerido para generar el keystore

```powershell
keytool -genkeypair -v -keystore android\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## 2. Build final

- Ejecuta `flutter pub get`.
- Ejecuta `flutter build appbundle --release`.
- Verifica que exista `build/app/outputs/bundle/release/app-release.aab`.

## 3. Play Console

- Crea la app nueva en Play Console.
- Usa el nombre comercial `NutrifynGo`.
- Sube el archivo `.aab` generado.
- Completa la ficha de Play con descripcion corta, descripcion larga, icono y capturas.

## 4. Politica de privacidad

- Publica el contenido de `PRIVACY_POLICY.md` en una URL accesible.
- Agrega esa URL en Play Console.

## 5. Data safety

- Declara que la app usa datos del perfil, pasos, recordatorios e imagen de perfil si el usuario la agrega.
- Declara que los datos se almacenan localmente en el dispositivo.
- Declara los permisos de actividad, notificaciones y reinicio si los mantienes.

## 6. Permisos

- `ACTIVITY_RECOGNITION`: necesario para conteo de pasos.
- `POST_NOTIFICATIONS`: necesario para recordatorios.
- `RECEIVE_BOOT_COMPLETED`: necesario para restaurar recordatorios al reiniciar.

## 7. Revision visual

- Cambia el icono por uno propio antes de publicar.
- Revisa que el nombre visible en launcher y capturas sea consistente con `NutrifynGo`.
- Prueba el widget en un telefono real antes de enviar la version.

## 8. Verificacion final

- Instala la build release en un dispositivo.
- Prueba registro de perfil, pasos, agua, calorias, rutinas, notificaciones y widget.
- Confirma que la app abre bien despues de reiniciar el telefono.
- Confirma que no hay textos de plantilla ni referencias viejas a `com.example` o `FitApp`.
