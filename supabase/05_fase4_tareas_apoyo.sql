-- TalentoActivo · Fase 4: tareas de apoyo, recomendaciones y panel de carga
-- Se ejecuta UNA sola vez en Supabase > SQL Editor (después de 01, 02, 03 y 04).
--
-- Regla de privacidad: la aplicación NUNCA escribe directo en "tareas". Todo pasa por
-- estas funciones, que comprueban quién es la persona y en qué estado está la tarea.
-- Los jefes nunca ven minutos de actividad: solo reciben una recomendación con motivos.
--
-- "Disponible" = menos de 40 % de actividad promedio en sus últimos 3 días laborales
-- completos (lunes a viernes, sin contar hoy). Un día laboral se mide sobre 8 horas.

-- ============ AUXILIAR (interna, no se llama desde la aplicación) ============

create function public.porcentaje_reciente(p uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select avg(pct) from (
    select 100.0 * sum(minutos_activos) / 480 as pct
    from public.actividad_bloques
    where perfil_id = p
      and (inicio at time zone 'America/Caracas')::date < (now() at time zone 'America/Caracas')::date
      and extract(isodow from inicio at time zone 'America/Caracas') <= 5
    group by (inicio at time zone 'America/Caracas')::date
    order by (inicio at time zone 'America/Caracas')::date desc
    limit 3
  ) d
$$;

revoke execute on function public.porcentaje_reciente(uuid) from public, anon, authenticated;

-- ============ EMPLEADO: MI DISPONIBILIDAD ============
-- Cada persona ve solo la suya.

create function public.mi_disponibilidad()
returns table (disponible boolean, porcentaje integer)
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(x < 40, false), round(x)::int
  from (select public.porcentaje_reciente(auth.uid()) as x) s
$$;

-- ============ JEFE: PUBLICAR Y CANCELAR ============

create function public.publicar_apoyo(
  p_titulo text,
  p_descripcion text,
  p_horas numeric,
  p_habilidades integer[]
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  nueva bigint;
begin
  if public.mi_rol() is distinct from 'jefe' then
    raise exception 'Solo los jefes de área pueden publicar tareas de apoyo.';
  end if;
  if coalesce(trim(p_titulo), '') = '' then
    raise exception 'Escribe un título para la tarea.';
  end if;
  if p_horas is null or p_horas <= 0 or p_horas > 99 then
    raise exception 'Las horas estimadas deben estar entre 0,5 y 99.';
  end if;

  insert into public.tareas (titulo, descripcion, tipo, area_id, creada_por, estado, horas_estimadas)
  values (
    trim(p_titulo),
    nullif(trim(coalesce(p_descripcion, '')), ''),
    'apoyo', public.mi_area(), auth.uid(), 'publicada', p_horas
  )
  returning id into nueva;

  insert into public.tarea_habilidades (tarea_id, habilidad_id)
  select distinct nueva, h from unnest(coalesce(p_habilidades, '{}')) as h;

  return nueva;
end;
$$;

create function public.cancelar_apoyo(p_tarea bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.tareas
  set estado = 'cancelada', asignada_a = null, asignada_en = null
  where id = p_tarea
    and creada_por = auth.uid()
    and tipo = 'apoyo'
    and estado in ('publicada', 'asignada');
  if not found then
    raise exception 'No se puede cancelar esta tarea.';
  end if;
end;
$$;

-- ============ JEFE: A QUIÉN RECOMENDAR (y por qué) ============
-- Solo personas de OTRAS áreas, empleados, que aceptaron la política de monitoreo vigente,
-- disponibles, que no rechazaron esta tarea
-- y que tengan al menos una de las habilidades pedidas (si la tarea pide alguna).
-- Puntaje de 0 a 100:  60 habilidades (nivel básico 1, intermedio 2, avanzado 3)
--                    + 25 cuánta holgura tiene
--                    + 15 pocas tareas abiertas.
-- Se devuelven los motivos en palabras; nunca los minutos de actividad.

create function public.recomendar_candidatos(p_tarea bigint)
returns table (
  perfil_id uuid,
  nombre text,
  cargo text,
  area text,
  puntaje integer,
  motivos text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t public.tareas%rowtype;
  pedidas integer;
begin
  select * into t from public.tareas
  where id = p_tarea and creada_por = auth.uid() and tipo = 'apoyo' and estado = 'publicada';
  if not found then
    raise exception 'Esta tarea no está disponible para recomendar.';
  end if;

  select count(*) into pedidas from public.tarea_habilidades where tarea_id = p_tarea;

  return query
  with cand as (
    select
      pf.id,
      pf.nombre,
      pf.cargo,
      ar.nombre as area,
      public.porcentaje_reciente(pf.id) as pct,
      (select count(*) from public.tareas x
        where x.asignada_a = pf.id and x.estado in ('asignada', 'en_curso')) as abiertas
    from public.perfiles pf
    join public.areas ar on ar.id = pf.area_id
    where pf.rol = 'empleado'
      and pf.area_id <> t.area_id
      and exists (
        select 1 from public.consentimientos co
        where co.perfil_id = pf.id and co.version = public.politica_version_actual()
      )
      and not exists (
        select 1 from public.tarea_rechazos r
        where r.tarea_id = p_tarea and r.perfil_id = pf.id
      )
  ),
  puntos as (
    select
      c.*,
      coalesce((
        select sum(case ph.nivel when 'avanzado' then 3 when 'intermedio' then 2 else 1 end)
        from public.perfil_habilidades ph
        join public.tarea_habilidades th on th.habilidad_id = ph.habilidad_id and th.tarea_id = p_tarea
        where ph.perfil_id = c.id
      ), 0) as pts_hab,
      (
        select array_agg(h.nombre || ' (' ||
          case ph.nivel when 'avanzado' then 'avanzado' when 'intermedio' then 'intermedio' else 'básico' end
          || ')' order by h.nombre)
        from public.perfil_habilidades ph
        join public.tarea_habilidades th on th.habilidad_id = ph.habilidad_id and th.tarea_id = p_tarea
        join public.habilidades h on h.id = ph.habilidad_id
        where ph.perfil_id = c.id
      ) as hab_texto
    from cand c
    where c.pct < 40
  )
  select
    p.id,
    p.nombre,
    p.cargo,
    p.area,
    round(
      case when pedidas > 0 then 60.0 * p.pts_hab / (3 * pedidas) else 0 end
      + 25.0 * (40 - p.pct) / 40
      + 15.0 * greatest(0, 1 - p.abiertas / 3.0)
    )::int,
    array_remove(array[
      case when p.hab_texto is not null then 'Tiene la habilidad: ' || array_to_string(p.hab_texto, ', ') end,
      'Tiene poca carga de trabajo esta semana',
      case when p.abiertas = 0 then 'No tiene tareas pendientes'
           when p.abiertas = 1 then 'Solo tiene 1 tarea abierta'
           else 'Tiene ' || p.abiertas || ' tareas abiertas' end
    ], null)
  from puntos p
  where pedidas = 0 or p.pts_hab > 0
  order by 5 desc, p.nombre
  limit 5;
end;
$$;

-- ============ JEFE: ASIGNAR ============

create function public.asignar_apoyo(p_tarea bigint, p_perfil uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Solo se puede asignar a alguien de la lista recomendada.
  if not exists (select 1 from public.recomendar_candidatos(p_tarea) r where r.perfil_id = p_perfil) then
    raise exception 'Esa persona no está en la lista de recomendados.';
  end if;

  update public.tareas
  set estado = 'asignada', asignada_a = p_perfil, asignada_en = now()
  where id = p_tarea and creada_por = auth.uid() and estado = 'publicada';
  if not found then
    raise exception 'La tarea ya no está publicada.';
  end if;
end;
$$;

-- ============ EMPLEADO: ACEPTAR O RECHAZAR ============
-- Al rechazar queda el motivo y la tarea vuelve a "publicada" para recomendar a otra persona.

create function public.responder_apoyo(p_tarea bigint, p_acepta boolean, p_motivo text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_acepta then
    update public.tareas
    set estado = 'en_curso', aceptada_en = now()
    where id = p_tarea and asignada_a = auth.uid() and tipo = 'apoyo' and estado = 'asignada';
    if not found then
      raise exception 'Esta tarea ya no está esperando tu respuesta.';
    end if;
  else
    update public.tareas
    set estado = 'publicada', asignada_a = null, asignada_en = null
    where id = p_tarea and asignada_a = auth.uid() and tipo = 'apoyo' and estado = 'asignada';
    if not found then
      raise exception 'Esta tarea ya no está esperando tu respuesta.';
    end if;
    insert into public.tarea_rechazos (tarea_id, perfil_id, motivo)
    values (p_tarea, auth.uid(), nullif(trim(coalesce(p_motivo, '')), ''));
  end if;
end;
$$;

-- ============ EMPLEADO: TERMINAR / JEFE: APROBAR ============

create function public.terminar_tarea(p_tarea bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.tareas
  set estado = 'en_revision', terminada_en = now()
  where id = p_tarea and asignada_a = auth.uid() and estado = 'en_curso';
  if not found then
    raise exception 'No se puede marcar esta tarea como terminada.';
  end if;
end;
$$;

create function public.aprobar_tarea(p_tarea bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.tareas
  set estado = 'aprobada', aprobada_en = now()
  where id = p_tarea
    and creada_por = auth.uid()
    and asignada_a <> auth.uid() -- nadie aprueba su propia tarea
    and public.mi_rol() = 'jefe'
    and estado = 'en_revision';
  if not found then
    raise exception 'No se puede aprobar esta tarea.';
  end if;
end;
$$;

-- ============ RR.HH.: PANEL DE CARGA ============
-- Semáforo por área:
--   rojo     = sobrecargada (actividad promedio de 85 % o más, o 3+ tareas atrasadas)
--   naranja  = tiene capacidad libre (alguien disponible)
--   verde    = carga equilibrada
-- "Atrasada" = tarea en curso o asignada desde antes del lunes de esta semana.

create function public.panel_carga()
returns table (
  area text,
  personas integer,
  promedio integer,
  disponibles integer,
  abiertas integer,
  atrasadas integer,
  apoyo_sin_asignar integer,
  semaforo text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  lunes timestamptz := date_trunc('week', now() at time zone 'America/Caracas') at time zone 'America/Caracas';
begin
  if public.mi_rol() is distinct from 'rh' then
    raise exception 'Solo Recursos Humanos puede ver el panel de carga.';
  end if;

  return query
  with base as (
    select
      ar.id as area_id,
      ar.nombre,
      pf.id as pid,
      pf.rol,
      public.porcentaje_reciente(pf.id) as pct
    from public.areas ar
    left join public.perfiles pf on pf.area_id = ar.id
  ),
  agr as (
    select
      b.area_id,
      b.nombre,
      count(b.pid)::int as personas,
      round(avg(b.pct))::int as promedio,
      count(*) filter (where b.rol = 'empleado' and b.pct < 40)::int as disponibles,
      coalesce(sum((select count(*) from public.tareas t
        where t.asignada_a = b.pid and t.estado in ('asignada', 'en_curso'))), 0)::int as abiertas,
      coalesce(sum((select count(*) from public.tareas t
        where t.asignada_a = b.pid and t.estado in ('asignada', 'en_curso') and t.creada_en < lunes)), 0)::int as atrasadas
    from base b
    group by b.area_id, b.nombre
  )
  select
    a.nombre,
    a.personas,
    a.promedio,
    a.disponibles,
    a.abiertas,
    a.atrasadas,
    (select count(*)::int from public.tareas t
      where t.tipo = 'apoyo' and t.estado = 'publicada' and t.area_id = a.area_id),
    case
      when coalesce(a.promedio, 0) >= 85 or a.atrasadas >= 3 then 'rojo'
      when a.disponibles > 0 then 'naranja'
      else 'verde'
    end
  from agr a
  order by case
      when coalesce(a.promedio, 0) >= 85 or a.atrasadas >= 3 then 1
      when a.disponibles > 0 then 2
      else 3
    end, a.nombre;
end;
$$;

create function public.personas_disponibles()
returns table (
  perfil_id uuid,
  nombre text,
  cargo text,
  area text,
  porcentaje integer,
  habilidades text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if public.mi_rol() is distinct from 'rh' then
    raise exception 'Solo Recursos Humanos puede ver quién está disponible.';
  end if;

  return query
  select
    pf.id, pf.nombre, pf.cargo, ar.nombre,
    round(public.porcentaje_reciente(pf.id))::int,
    (select array_agg(h.nombre order by h.nombre)
       from public.perfil_habilidades ph
       join public.habilidades h on h.id = ph.habilidad_id
      where ph.perfil_id = pf.id)
  from public.perfiles pf
  join public.areas ar on ar.id = pf.area_id
  where pf.rol = 'empleado' and public.porcentaje_reciente(pf.id) < 40
  order by 5, pf.nombre;
end;
$$;

-- ============ PERMISOS ============
-- Por defecto Supabase deja ejecutar funciones a todo el mundo. Aquí solo a quien inició sesión.

revoke execute on function
  public.mi_disponibilidad(),
  public.publicar_apoyo(text, text, numeric, integer[]),
  public.cancelar_apoyo(bigint),
  public.recomendar_candidatos(bigint),
  public.asignar_apoyo(bigint, uuid),
  public.responder_apoyo(bigint, boolean, text),
  public.terminar_tarea(bigint),
  public.aprobar_tarea(bigint),
  public.panel_carga(),
  public.personas_disponibles()
from public, anon;

grant execute on function
  public.mi_disponibilidad(),
  public.publicar_apoyo(text, text, numeric, integer[]),
  public.cancelar_apoyo(bigint),
  public.recomendar_candidatos(bigint),
  public.asignar_apoyo(bigint, uuid),
  public.responder_apoyo(bigint, boolean, text),
  public.terminar_tarea(bigint),
  public.aprobar_tarea(bigint),
  public.panel_carga(),
  public.personas_disponibles()
to authenticated;
