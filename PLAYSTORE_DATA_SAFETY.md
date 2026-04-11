# Data Safety Para Play Console - NutrifynGo

Esta guia esta basada en el estado actual de la app:

- Nombre: NutrifynGo
- Package id: com.jaae.nutrifyngo
- Guardado: local en el dispositivo
- Permisos declarados: actividad fisica, notificaciones y reinicio al arrancar
- No hay inicio de sesion social activo
- No hay backend activo para sincronizacion en nube en la experiencia actual

## Resumen recomendado para Play Console

### ¿Tu app recopila o comparte algun tipo de dato?

Respuesta recomendada:

- Si, recopila ciertos datos introducidos por el usuario o generados por el uso de la app.
- No, no comparte datos con terceros.

## Datos que puedes declarar como recopilados

### 1. Informacion personal

Subtipo recomendado:

- Nombre
- Fotos o videos opcionalmente, si el usuario agrega imagen de perfil

Uso:

- Funcionalidad de la app
- Personalizacion

Tratamiento recomendado:

- Los datos no se comparten con terceros
- Los datos se almacenan localmente en el dispositivo
- La recopilacion es opcional para la foto, y requerida para ciertas partes del perfil

### 2. Salud y actividad fisica

Subtipo recomendado:

- Actividad fisica o pasos

Uso:

- Funcionalidad de la app
- Analitica interna de progreso dentro de la app

Tratamiento recomendado:

- No se comparte con terceros
- Se usa para mostrar progreso, metas y widget
- Se almacena localmente en el dispositivo

### 3. Informacion de la app y rendimiento

Respuesta recomendada:

- No, salvo que agregues herramientas externas de analitica o crash reporting

## Respuestas practicas para el formulario

### ¿Los datos se procesan de forma cifrada en transito?

Respuesta recomendada:

- No aplica para los datos locales actuales

Nota:

Si Play obliga a marcar algo para trafico en red por funciones concretas, revisalo segun la implementacion final. Hoy la app funciona principalmente con almacenamiento local.

### ¿Los usuarios pueden solicitar que se eliminen sus datos?

Respuesta recomendada:

- Si

Justificacion:

- Pueden borrar la app y sus datos locales
- Pueden editar o reemplazar sus datos dentro de la app

## Permisos y justificacion

### ACTIVITY_RECOGNITION

Uso recomendado en Play:

- Se usa para contar pasos y actualizar el progreso diario del usuario

### POST_NOTIFICATIONS

Uso recomendado en Play:

- Se usa para recordatorios configurados por el usuario

### RECEIVE_BOOT_COMPLETED

Uso recomendado en Play:

- Se usa para restaurar recordatorios despues de reiniciar el dispositivo

## Texto corto sugerido para responder revisiones

NutrifynGo almacena principalmente la informacion en el dispositivo del usuario para mostrar perfil, pasos, agua, calorias, rutinas y widget de progreso. La app no vende ni comparte datos personales con terceros.

## Antes de enviar

Verifica esto en Play Console antes de publicar:

1. Si mantienes la foto de perfil, declara imagenes como dato opcional.
2. Si luego agregas Firebase, analitica o sincronizacion real en nube, esta hoja deja de ser suficiente y hay que actualizarla.
3. La politica de privacidad publicada debe coincidir con estas respuestas.
4. No marques que no recopilas nada, porque la app si procesa perfil, pasos y foto opcional.
