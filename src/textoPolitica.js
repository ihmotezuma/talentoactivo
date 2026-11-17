// Texto de la política de uso del monitoreo.
// La versión debe ser igual a la función politica_version_actual() de Supabase
// (supabase/03_actividad_tareas.sql). Si cambias el texto, cambia ambas y
// todas las personas tendrán que aceptarla de nuevo.
export const VERSION_POLITICA = '2026-11-v1'

export const PUNTOS_POLITICA = [
  {
    titulo: 'Qué se mide',
    texto:
      'Cada minuto, el programa revisa si usaste el teclado o el ratón: activo o inactivo. Cada 5 minutos envía a TalentoActivo solo dos números: los minutos activos y los minutos inactivos.',
  },
  {
    titulo: 'Qué NO se mide',
    texto:
      'Nunca captura pantallas, lo que escribes, tus correos, las páginas web que visitas, tus archivos, la cámara ni el micrófono.',
  },
  {
    titulo: 'Quién lo ve',
    texto:
      'Tú ves todos tus datos. Recursos Humanos ve tus totales para detectar quién puede apoyar a otras áreas. Los jefes de área no ven tus minutos: solo reciben recomendaciones de a quién pedirle apoyo.',
  },
  {
    titulo: 'Por cuánto tiempo se guarda',
    texto:
      'El detalle de cada 5 minutos se guarda 30 días. Después queda solo el total de cada semana, durante 1 año. Pasado ese plazo se borra.',
  },
  {
    titulo: 'Para qué se usa',
    texto:
      'Para repartir mejor el trabajo entre las áreas, no para sancionar a nadie. Un número bajo de actividad nunca es una falta: es una señal de que podrías ayudar donde hace falta.',
  },
  {
    titulo: 'Tú tienes el control',
    texto:
      'El programa siempre está visible en tu computadora. Puedes pausarlo cuando quieras y desinstalarlo cuando quieras.',
  },
]
