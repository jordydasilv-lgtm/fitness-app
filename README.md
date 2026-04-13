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

## Build iPhone (macOS)

> iOS solo puede compilarse desde macOS con Xcode instalado.

```bash
flutter clean
flutter pub get
cd ios
pod repo update
pod install
cd ..
flutter build ios --release
```

### Ajustes en Xcode antes de publicar

- Abre `ios/Runner.xcworkspace` en Xcode.
- En `Runner > Signing & Capabilities`, selecciona tu Team.
- Verifica el Bundle Identifier: `com.jaae.nutrifyngo`.
- Sube el Deployment Target si tu cuenta/proyecto lo requiere.

## Codemagic

Este repo ya incluye `codemagic.yaml` para builds de Android e iOS.

### Variables recomendadas en Codemagic (Environment variables)

- `CM_KEYSTORE` (base64 del archivo `upload-keystore.jks`)
- `CM_KEYSTORE_PASSWORD`
- `CM_KEY_ALIAS`
- `CM_KEY_PASSWORD`

Si no defines estas variables, Android se compila sin firma de release.

### Flujo rapido

1. Sube este proyecto a GitHub en la rama `main`.
2. En Codemagic: `Add application` -> conecta este repositorio.
3. Selecciona configuracion desde `codemagic.yaml`.
4. Ejecuta `android-release` para AAB/APK.
5. Ejecuta `ios-release` para build iOS sin firma (`--no-codesign`).
