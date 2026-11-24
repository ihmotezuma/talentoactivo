-- TalentoActivo · Fase 7: Mi semana (empleado) y Semana de mi equipo (jefe)
-- Se ejecuta UNA sola vez en Supabase > SQL Editor.

create or replace function public.otorgar_habilidades_apoyo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.tipo = 'apoyo'
     and new.estado = 'aprobada'
     and old.estado is distinct from 'aprobada'
     and new.asignada_a is not null then
    insert into public.perfil_habilidades (perfil_id, habilidad_id, nivel)
    select new.asignada_a, th.habilidad_id, 'basico'
    from public.tarea_habilidades th
    where th.tarea_id = new.id
    on conflict (perfil_id, habilidad_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_otorgar_habilidades_apoyo on public.tareas;
create trigger trg_otorgar_habilidades_apoyo
  after update of estado on public.tareas
  for each row
  execute function public.otorgar_habilidades_apoyo();

create or replace function public.semana_equipo()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_area integer := public.mi_area();
  v_inicio_semana timestamptz := date_trunc('week', now() at time zone 'America/Caracas') at time zone 'America/Caracas';
  v_resumen jsonb;
  v_apoyos jsonb;
begin
  if public.mi_rol() is distinct from 'jefe' then
    raise exception 'Solo disponible para jefes de área.';
  end if;

  select jsonb_build_object(
    'aprobadas', count(*) filter (where estado = 'aprobada' and aprobada_en >= v_inicio_semana),
    'en_curso', count(*) filter (where estado in ('asignada', 'en_curso', 'en_revision')),
    'horas_aprobadas', coalesce(sum(horas_estimadas) filter (where estado = 'aprobada' and aprobada_en >= v_inicio_semana), 0)
  )
  into v_resumen
  from public.tareas
  where area_id = v_area;

  select coalesce(jsonb_agg(fila order by fila.aprobada_en desc), '[]'::jsonb)
  into v_apoyos
  from (
    select
      t.id,
      t.titulo,
      t.horas_estimadas,
      t.aprobada_en,
      p.nombre as colaborador,
      a.nombre as area_origen,
      coalesce(
        (select jsonb_agg(h.nombre order by h.nombre)
         from public.tarea_habilidades th
         join public.habilidades h on h.id = th.habilidad_id
         where th.tarea_id = t.id),
        '[]'::jsonb
      ) as habilidades
    from public.tareas t
    join public.perfiles p on p.id = t.asignada_a
    join public.areas a on a.id = p.area_id
    where t.area_id = v_area
      and t.tipo = 'apoyo'
      and t.estado = 'aprobada'
    order by t.aprobada_en desc
    limit 10
  ) fila;

  return jsonb_build_object(
    'resumen', v_resumen,
    'apoyos', v_apoyos
  );
end;
$$;
