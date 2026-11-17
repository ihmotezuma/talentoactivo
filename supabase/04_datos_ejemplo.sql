-- TalentoActivo · Fase 3 · Paso 2: actividad y tareas de ejemplo (8 semanas)
-- Se ejecuta en Supabase > SQL Editor, después del archivo 03.
-- Crea la función cargar_datos_ejemplo() y la ejecuta una vez.
-- Se puede volver a ejecutar cuando quieras (por ejemplo, el día antes de la
-- presentación): borra SOLO lo marcado como "ejemplo" y lo genera de nuevo
-- con fechas al día. No toca la actividad real que envíe el programa.
--
-- Qué verás en la demo:
--   · Cuentas (Alejandro, Paola, Andrés): muy activos y con tareas atrasadas → sobrecargada.
--   · María y Luis (Consumer Insights): menos del 40 % activos en sus últimos días laborales.
--   · José Ángel: baja un poco (50 %), pero NO llega al umbral → no aparece como disponible.
--   · El resto: actividad normal (64 % a 78 %).

create or replace function public.cargar_datos_ejemplo()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  hoy date := (now() at time zone 'America/Caracas')::date;
  lunes date := date_trunc('week', (now() at time zone 'America/Caracas'))::date;
  p record;
  k int;
  i int;
  n int;
  a int;
  estado_t text;
  base timestamptz;
  creada timestamptz;
  titulos text[];
  jefe_id uuid;
  em_cuentas text[] := array['alejandro.fernandez@delfos.example', 'paola.marquez@delfos.example', 'andres.colmenares@delfos.example'];
begin
  -- Borra solo lo de ejemplo (las tareas arrastran habilidades y rechazos).
  delete from public.tareas where origen = 'ejemplo';
  delete from public.actividad_bloques where origen = 'ejemplo';
  delete from public.actividad_semanal where origen = 'ejemplo';

  -- ============ ACTIVIDAD ============
  -- Se generan bloques de 5 minutos, de 9:00 a 17:00 (hora de Caracas), de lunes
  -- a viernes, para los últimos 62 días. Los últimos 30 días quedan como bloques
  -- y lo anterior queda archivado en totales semanales, igual que haría la
  -- limpieza automática.
  with dias as (
    select dia, row_number() over (order by dia desc) as rk
    from (select hoy - g as dia from generate_series(1, 62) g) d
    where extract(isodow from dia) <= 5
  ),
  gente as (
    select pf.id, u.email
    from public.perfiles pf
    join auth.users u on u.id = pf.id
    where u.email like '%@delfos.example'
  ),
  fraccion as (
    select
      g.id, g.email, d.dia,
      -- fracción de tiempo activo de esa persona ese día
      greatest(0.05, least(0.99,
        case
          when g.email = 'maria.perez@delfos.example' then
            case when d.rk <= 5 then 0.27 when d.rk <= 10 then 0.52 else 0.72 end
          when g.email = 'luis.gomez@delfos.example' then
            case when d.rk <= 4 then 0.31 else 0.70 end
          when g.email = 'joseangel.torres@delfos.example' then
            case when d.rk <= 3 then 0.50 else 0.70 end
          when g.email = any (em_cuentas) then
            case when d.rk <= 15 then 0.94 else 0.84 end
          else 0.64 + (abs(hashtext(g.email)) % 15) / 100.0
        end
        + ((abs(hashtext(g.email || d.dia::text)) % 1000) / 1000.0 - 0.5) * 0.10
      )) as f
    from gente g cross join dias d
  ),
  sint as materialized (
    select
      fr.id as perfil_id,
      fr.dia,
      ((fr.dia + time '09:00') + b * interval '5 minutes') at time zone 'America/Caracas' as inicio,
      least(5, floor(5 * fr.f + (abs(hashtext(fr.email || fr.dia::text || b::text)) % 1000) / 1000.0))::int as activos
    from fraccion fr cross join generate_series(0, 95) b
  ),
  bloques as (
    insert into public.actividad_bloques (perfil_id, inicio, minutos_activos, minutos_inactivos, origen)
    select perfil_id, inicio, activos, 5 - activos, 'ejemplo'
    from sint
    where dia >= hoy - 30
    returning 1
  )
  insert into public.actividad_semanal (perfil_id, semana, minutos_activos, minutos_inactivos, origen)
  select perfil_id, date_trunc('week', dia::timestamp)::date, sum(activos), sum(5 - activos), 'ejemplo'
  from sint
  where dia < hoy - 30
  group by perfil_id, date_trunc('week', dia::timestamp)::date;

  -- ============ TAREAS REGULARES (6 semanas, de la actual a 5 atrás) ============
  for p in
    select pf.id, pf.area_id, pf.rol, u.email, ar.nombre as area
    from public.perfiles pf
    join auth.users u on u.id = pf.id
    join public.areas ar on ar.id = pf.area_id
    where u.email like '%@delfos.example'
  loop
    titulos := case p.area
      when 'Consumer Insights' then array['Codificar entrevistas del estudio de lácteos', 'Redactar hallazgos cualitativos', 'Preparar guía para grupo focal', 'Analizar respuestas abiertas de la encuesta', 'Resumen ejecutivo del estudio de bebidas']
      when 'Trabajo de Campo' then array['Coordinar encuestas en Caracas', 'Supervisar levantamiento en tiendas', 'Validar cuestionarios recibidos', 'Capacitar a los encuestadores', 'Reporte de avance de campo']
      when 'Análisis de Datos' then array['Limpiar base de datos de la encuesta', 'Tablas cruzadas del estudio', 'Armar tablero de resultados', 'Revisar el tamaño de la muestra', 'Modelo de segmentación de clientes']
      when 'Cuentas' then array['Preparar propuesta para cliente', 'Presentar resultados al cliente', 'Dar seguimiento a cotización', 'Reunión de avance con cliente', 'Redactar informe final para cliente', 'Actualizar cronograma del proyecto']
      else array['Actualizar descriptivos de cargo', 'Organizar capacitación interna']
    end;
    select id into jefe_id from public.perfiles where area_id = p.area_id and rol = 'jefe' limit 1;
    jefe_id := coalesce(jefe_id, p.id);

    for k in 0..5 loop
      -- cuántas tareas tuvo esa semana (n) y cuántas quedaron aprobadas (a)
      n := case
        when p.email = any (em_cuentas) then case when k = 0 then 5 when k <= 2 then 6 else 4 end
        when p.email = 'maria.perez@delfos.example' then case when k <= 1 then 1 else 3 end
        when p.email = 'luis.gomez@delfos.example' then case when k = 0 then 1 when k = 1 then 2 else 3 end
        when p.rol = 'rh' then 2
        else case when k = 0 then 2 else 3 end
      end;
      a := case
        when k = 0 then 0
        when p.email = any (em_cuentas) then case when k <= 2 then 3 else 4 end
        else n
      end;

      for i in 1..n loop
        estado_t := case
          when k = 0 then case when i = 1 and n > 1 then 'en_revision' else 'en_curso' end
          when i <= a then 'aprobada'
          when i = a + 1 and k = 1 then 'en_revision'
          else 'en_curso'
        end;
        base := ((lunes - k * 7 + ((i - 1) % 3)) + time '09:00') at time zone 'America/Caracas';
        creada := least(base, now() - interval '2 hours');

        insert into public.tareas (
          titulo, tipo, area_id, creada_por, asignada_a, estado, horas_estimadas,
          creada_en, asignada_en, aceptada_en, terminada_en, aprobada_en, origen
        ) values (
          titulos[1 + (abs(hashtext(p.email)) + k * 7 + i) % array_length(titulos, 1)],
          'regular', p.area_id, jefe_id, p.id, estado_t,
          2 + (abs(hashtext(p.email || k::text || i::text)) % 5),
          creada, creada, creada,
          case when estado_t in ('en_revision', 'aprobada')
               then least(base + interval '2 days', now() - interval '1 hour') end,
          case when estado_t = 'aprobada'
               then least(base + interval '3 days', now() - interval '1 hour') end,
          'ejemplo'
        );
      end loop;
    end loop;
  end loop;

  -- ============ TAREAS DE APOYO ============
  -- sem = cuántas semanas atrás se publicó (0 = esta semana).
  -- Las dos últimas están "publicadas": Cuentas pide ayuda y nadie la tiene todavía.
  with v(titulo, descripcion, area, jefe, ayuda, estado, horas, sem, habilidad) as (
    values
    ('Redactar resumen de estudio para cliente', 'Resumir en dos páginas los resultados del estudio de marca.', 'Cuentas', 'alejandro.fernandez@delfos.example', 'valentina.rios@delfos.example', 'aprobada', 4, 4, 'Redacción de informes'),
    ('Redactar informe final del estudio de bebidas', 'Informe final con hallazgos y recomendaciones para el cliente.', 'Cuentas', 'alejandro.fernandez@delfos.example', 'maria.perez@delfos.example', 'aprobada', 5, 3, 'Redacción de informes'),
    ('Armar gráficos para la presentación al cliente', 'Gráficos claros de los resultados del tercer trimestre.', 'Cuentas', 'alejandro.fernandez@delfos.example', 'sofia.navarro@delfos.example', 'aprobada', 5, 3, 'Visualización de datos'),
    ('Transcribir y codificar los grupos focales', 'Transcripción y codificación de tres sesiones.', 'Consumer Insights', 'andrea.villalobos@delfos.example', 'daniela.castillo@delfos.example', 'aprobada', 6, 2, 'Transcripción y codificación'),
    ('Limpiar la base de la encuesta nacional', 'Revisar duplicados y respuestas incompletas en Excel.', 'Análisis de Datos', 'gabriela.sanchez@delfos.example', 'joseangel.torres@delfos.example', 'aprobada', 3, 2, 'Excel avanzado'),
    ('Preparar presentación de resultados', 'Presentación de 15 láminas para el comité del cliente.', 'Cuentas', 'alejandro.fernandez@delfos.example', 'valentina.rios@delfos.example', 'aprobada', 4, 1, 'Presentaciones'),
    ('Preparar propuesta para cliente nuevo', 'Propuesta de servicios para un cliente del sector retail.', 'Cuentas', 'alejandro.fernandez@delfos.example', 'valentina.rios@delfos.example', 'aprobada', 5, 1, 'Redacción de informes'),
    ('Redactar informe de resultados para cliente retail', 'Informe de hallazgos del estudio de tiendas, con recomendaciones.', 'Cuentas', 'alejandro.fernandez@delfos.example', null, 'publicada', 6, 0, 'Redacción de informes'),
    ('Preparar presentación de avance para cliente', 'Presentación corta del avance del estudio para la reunión del jueves.', 'Cuentas', 'alejandro.fernandez@delfos.example', null, 'publicada', 4, 0, 'Presentaciones')
  ),
  ins as (
    insert into public.tareas (
      titulo, descripcion, tipo, area_id, creada_por, asignada_a, estado, horas_estimadas,
      creada_en, asignada_en, aceptada_en, terminada_en, aprobada_en, origen
    )
    select
      v.titulo, v.descripcion, 'apoyo', ar.id, j.id, h.id, v.estado, v.horas,
      least(t.base, now() - interval '2 hours'),
      case when h.id is not null then least(t.base, now() - interval '2 hours') + interval '3 hours' end,
      case when v.estado in ('en_curso', 'en_revision', 'aprobada') then t.base + interval '1 day' end,
      case when v.estado in ('en_revision', 'aprobada') then t.base + interval '3 days' end,
      case when v.estado = 'aprobada' then t.base + interval '4 days' end,
      'ejemplo'
    from v
    cross join lateral (
      select ((lunes - v.sem * 7) + time '09:00') at time zone 'America/Caracas' as base
    ) t
    join public.areas ar on ar.nombre = v.area
    join auth.users j on j.email = v.jefe
    left join auth.users h on h.email = v.ayuda
    returning id, titulo
  )
  insert into public.tarea_habilidades (tarea_id, habilidad_id)
  select ins.id, hb.id
  from ins
  join v on v.titulo = ins.titulo
  join public.habilidades hb on hb.nombre = v.habilidad;

  -- Un rechazo de ejemplo: Luis dijo que no a la propuesta; luego la tomó Valentina.
  insert into public.tarea_rechazos (tarea_id, perfil_id, motivo, creado_en)
  select t.id, u.id, 'Esta semana estoy cerrando un informe y no llego.', t.creada_en + interval '1 hour'
  from public.tareas t, auth.users u
  where t.origen = 'ejemplo'
    and t.titulo = 'Preparar propuesta para cliente nuevo'
    and t.tipo = 'apoyo'
    and u.email = 'luis.gomez@delfos.example';
end;
$$;

-- Solo se puede ejecutar desde el SQL Editor, nunca desde la aplicación.
revoke execute on function public.cargar_datos_ejemplo() from public, anon, authenticated;

select public.cargar_datos_ejemplo();
