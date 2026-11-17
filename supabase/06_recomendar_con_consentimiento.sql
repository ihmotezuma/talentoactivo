-- TalentoActivo · Fase 4 · Parche: solo se recomienda a quien aceptó la política de monitoreo
-- Se ejecuta UNA vez en Supabase > SQL Editor (después del 05). Se puede repetir sin problema.

-- 1) La recomendación ahora exige la aceptación de la política vigente.
create or replace function public.recomendar_candidatos(p_tarea bigint)
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

-- 2) Las 14 personas de ejemplo aceptan la política vigente (para que la demo recomiende).
insert into public.consentimientos (perfil_id, version)
select pf.id, public.politica_version_actual()
from public.perfiles pf
join auth.users u on u.id = pf.id
where u.email like '%@delfos.example'
on conflict (perfil_id, version) do nothing;
