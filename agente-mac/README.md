# Programa de monitoreo para Mac (Fase 5)

App de barra de menú (`TA ●`) que mide si la persona está **activa o inactiva** y envía a
TalentoActivo, cada 5 minutos, solo dos números: minutos activos y minutos inactivos.
Cumple lo que dice la política de uso (`src/textoPolitica.js`).

## Cómo funciona

- **Cada minuto** pregunta al sistema cuántos segundos hace que se usó el teclado o el ratón
  (`CGEventSource.secondsSinceLastEventType`). Menos de 60 s = minuto activo.
  No lee teclas, pantallas, apps ni páginas web, y no pide permisos especiales de macOS.
- **Cada 5 minutos** agrupa los minutos en un bloque y lo envía a la tabla `actividad_bloques`
  de Supabase. Cada bloque lleva: quién, cuándo empieza, minutos activos y minutos inactivos.
- **Inicia sesión como la persona** (correo y contraseña de la web). Guarda solo el permiso de
  sesión, nunca la contraseña, en `~/Library/Application Support/TalentoActivo` (permisos 600).
  Como entra con su propia sesión, las reglas de Supabase (RLS) hacen cumplir que solo se envíe
  actividad propia y solo si aceptó la política vigente.
- **Sin internet:** guarda hasta una semana de bloques y los envía al volver la conexión
  (si se repite un bloque, se ignora).
- **Si Supabase rechaza el envío por falta de consentimiento:** deja de medir y lo avisa en el menú.
- **Visible y bajo control:** el menú permite Pausar/Reanudar, Cerrar sesión, ver qué mide y
  Desinstalar (borra sus datos locales, el inicio automático y manda la app a la papelera).
- Arranca solo al iniciar sesión en la Mac (LaunchAgent `ve.ucab.talentoactivo.agente`).

## Construir

```
cd agente-mac
./construir.sh        # necesita xcode-select --install y el .env de la raíz
```

Genera `public/TalentoActivo-Mac.zip` (Mac Intel y chip Apple), que la web ofrece como descarga.
Después hay que hacer commit y push para que Cloudflare lo publique.

Comprobar la lógica sin abrir nada: `swiftc Fuentes/*.swift -o prueba && ./prueba --autoprueba`.

## Limitación conocida

La app está firmada "ad hoc" (sin cuenta de Apple Developer, que cuesta 99 USD al año), así que
macOS pide aprobarla la primera vez en Ajustes del Sistema > Privacidad y seguridad.
