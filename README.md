# NutrifynGo

Aplicacion Flutter para registrar calorias, agua, pasos, rutinas y progreso diario.

## Estado para Play Store

- Nombre visible: `NutrifynGo`
- Package id Android: `com.jaae.nutrifyngo`
- Guardado: local en el dispositivo
- Widget Android: progreso diario con calorias, agua y pasos

## Pendiente antes de publicar

- Crear tu propio `key.properties` con el keystore de release.
- Generar icono final y capturas para la ficha de Play.
- Publicar politica de privacidad si mantienes permisos y notificaciones.

## Build release

```bash
flutter pub get
flutter build appbundle --release
```
