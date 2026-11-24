# TalentoActivo

Mercado interno de tareas con IA para equilibrar la carga de trabajo entre áreas.

Proyecto final de la materia **Inteligencia Artificial: Aplicaciones** (UCAB, Relaciones Industriales).

## ¿Qué es?

En las empresas que trabajan por proyectos hay semanas de mucho trabajo y semanas sin nada que hacer.
TalentoActivo permite que:

- Los empleados con semana floja marquen, de forma confidencial, que están **disponibles**.
- Los jefes de áreas con mucho trabajo **publiquen tareas de apoyo**.
- Un sistema de recomendación **sugiera a las mejores personas** y explique por qué.
- RR.HH. vea un **panel de carga** con semáforo 🔴🟢🟠, alertas y un **Asistente de IA**.

## Cómo correrlo

1. Copiar `.env.example` como `.env` y pegar las claves de Supabase.
2. `npm install`
3. `npm run dev`

## Enlace público

https://talentoactivo.pages.dev

## Avance por fases

- [x] **Fase 1:** cimientos. Proyecto en GitHub, base de datos en Supabase y página de bienvenida publicada en Cloudflare Pages.
- [x] **Fase 2:** inicio de sesión con correo y contraseña, 3 roles (empleado, jefe, RR.HH.), 14 personas de ejemplo de la Consultora Delfos y reglas de privacidad en la base de datos.
- [x] **Fase 3:** consentimiento del monitoreo, tablas de actividad y tareas, y datos de ejemplo de 8 semanas.
- [x] **Fase 4:** tareas de apoyo (publicar, recomendar, asignar, aceptar o rechazar, terminar y aprobar) y panel de carga de RR.HH. Scripts: `supabase/05_fase4_tareas_apoyo.sql`, `06_recomendar_con_consentimiento.sql` y `07_no_aprobarse_a_si_mismo.sql`.
- [x] **Fase 5:** programas de monitoreo multiplataforma para Mac (`agente-mac/`) y Windows (`agente-windows/`): miden actividad/inactividad cada minuto y envían bloques cada 5 minutos con cola offline.
- [x] **Fase 6:** Asistente de IA para RR.HH. conectado a OpenAI mediante Supabase Edge Functions (`asistente-rh`) para analizar sobrecarga, riesgos y reasignación de talento.
- [x] **Fase 7:** vista **Mi semana** para empleados (actividad semanal, tareas y habilidades ganadas en apoyos) y **Semana de mi equipo** para jefes de área (`supabase/08_fase7_mi_semana.sql`).
