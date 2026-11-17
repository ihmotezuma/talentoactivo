-- TalentoActivo · Fase 3 · Paso 1: consentimiento, actividad, tareas y reglas de privacidad
-- Se ejecuta UNA sola vez en Supabase > SQL Editor (después de 01 y 02).

-- ============ FUNCIONES AUXILIARES ============

-- Área de quien tiene la sesión iniciada.
create function public.mi_area()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select area_id from public.perfiles where id = auth.uid()
$$;

-- Versión vigente de la política de uso. Si el texto cambia, se cambia aquí
-- (y en src/textoPolitica.js) y todas las personas deben aceptarla de nuevo.
create function public.politica_version_actual()
returns text
language sql
immutable
as $$
  select '2026-11-v1'::text
$$;

-- ============ CONSENTIMIENTO ============
-- Una fila por persona y versión de la política. Solo se puede agregar:
-- nadie puede editar ni borrar una aceptación (no hay reglas para eso).

create table public.consentimientos (
  id bigserial primary key,
  perfil_id uuid not null references public.perfiles (id) on delete cascade,
  version text not null,
  aceptado_en timestamptz not null default now(),
  unique (perfil_id, version)
);

alter table public.consentimientos enable row level security;

create policy "ver mi consentimiento o RH" on public.consentimientos
  for select to authenticated
  using (perfil_id = auth.uid() or public.mi_rol() = 'rh');

create policy "aceptar la politica vigente" on public.consentimientos
  for insert to authenticated
  with check (
    perfil_id = auth.uid()
    and version = public.politica_version_actual()
  );

-- ¿La persona con sesión iniciada aceptó la política vigente?
create function public.tiene_consentimiento()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.consentimientos
    where perfil_id = auth.uid()
      and version = public.politica_version_actual()
  )
$$;

-- ============ ACTIVIDAD DE LA COMPUTADORA ============
-- El programa envía, cada 5 minutos, SOLO dos números: minutos activos e inactivos.
-- No hay ninguna columna para pantallas, teclas, correos ni páginas web.

create table public.actividad_bloques (
  perfil_id uuid not null references public.perfiles (id) on delete cascade,
  inicio timestamptz not null,
  minutos_activos smallint not null check (minutos_activos >= 0),
  minutos_inactivos smallint not null check (minutos_inactivos >= 0),
  origen text not null default 'agente' check (origen in ('agente', 'ejemplo')),
  primary key (perfil_id, inicio),
  check (minutos_activos + minutos_inactivos between 1 and 10)
);

-- Totales por semana (el lunes marca la semana). Aquí se archivan los bloques
-- cuando cumplen 30 días. Se conservan 1 año.
create table public.actividad_semanal (
  perfil_id uuid not null references public.perfiles (id) on delete cascade,
  semana date not null,
  minutos_activos integer not null,
  minutos_inactivos integer not null,
  origen text not null default 'agente' check (origen in ('agente', 'ejemplo')),
  primary key (perfil_id, semana)
);

alter table public.actividad_bloques enable row level security;
alter table public.actividad_semanal enable row level security;

-- La ve la propia persona y Recursos Humanos. Los jefes NO ven minutos de nadie.
create policy "ver mi actividad o RH" on public.actividad_bloques
  for select to authenticated
  using (perfil_id = auth.uid() or public.mi_rol() = 'rh');

create policy "ver mi actividad semanal o RH" on public.actividad_semanal
  for select to authenticated
  using (perfil_id = auth.uid() or public.mi_rol() = 'rh');

-- Solo se puede enviar actividad propia y solo si se aceptó la política vigente.
create policy "enviar mi actividad con consentimiento" on public.actividad_bloques
  for insert to authenticated
  with check (
    perfil_id = auth.uid()
    and origen = 'agente'
    and public.tiene_consentimiento()
  );

-- Vistas de apoyo (respetan las mismas reglas de privacidad de las tablas).
-- Un día laboral se mide sobre 8 horas (480 minutos), hora de Caracas.
create view public.actividad_diaria
with (security_invoker = true) as
select
  perfil_id,
  (inicio at time zone 'America/Caracas')::date as dia,
  sum(minutos_activos)::int as minutos_activos,
  sum(minutos_inactivos)::int as minutos_inactivos,
  round(100.0 * sum(minutos_activos) / 480)::int as porcentaje_activo
from public.actividad_bloques
group by perfil_id, (inicio at time zone 'America/Caracas')::date;

-- Totales por semana = semanas archivadas + bloques que aún no se archivan.
create view public.actividad_semanal_total
with (security_invoker = true) as
select
  perfil_id,
  semana,
  sum(minutos_activos)::int as minutos_activos,
  sum(minutos_inactivos)::int as minutos_inactivos
from (
  select perfil_id, semana, minutos_activos, minutos_inactivos
  from public.actividad_semanal
  union all
  select
    perfil_id,
    date_trunc('week', inicio at time zone 'America/Caracas')::date,
    minutos_activos,
    minutos_inactivos
  from public.actividad_bloques
) t
group by perfil_id, semana;

-- ============ CUÁNTO TIEMPO SE GUARDA ============
-- Detalle de 5 en 5 minutos: 30 días. Pasado ese plazo se suma a su semana y se borra.
-- Totales semanales: 1 año. Pasado ese plazo se borran.
create function public.purgar_actividad()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  with viejos as (
    delete from public.actividad_bloques
    where inicio < now() - interval '30 days'
    returning perfil_id, inicio, minutos_activos, minutos_inactivos, origen
  )
  insert into public.actividad_semanal (perfil_id, semana, minutos_activos, minutos_inactivos, origen)
  select
    perfil_id,
    date_trunc('week', inicio at time zone 'America/Caracas')::date,
    sum(minutos_activos),
    sum(minutos_inactivos),
    min(origen)
  from viejos
  group by perfil_id, date_trunc('week', inicio at time zone 'America/Caracas')::date
  on conflict (perfil_id, semana) do update set
    minutos_activos = public.actividad_semanal.minutos_activos + excluded.minutos_activos,
    minutos_inactivos = public.actividad_semanal.minutos_inactivos + excluded.minutos_inactivos;

  delete from public.actividad_semanal
  where semana < current_date - interval '1 year';
end;
$$;

revoke execute on function public.purgar_actividad() from public, anon, authenticated;

-- Programa la limpieza todos los días si la extensión pg_cron está disponible.
-- Si no lo está, el script sigue sin error y avisa.
do $$
begin
  create extension if not exists pg_cron;
  perform cron.schedule('purgar-actividad', '0 7 * * *', 'select public.purgar_actividad()');
exception when others then
  raise notice 'pg_cron no está disponible (%). Activa la extensión en Database > Extensions y vuelve a ejecutar este bloque.', sqlerrm;
end $$;

-- ============ TAREAS ============
-- "regular": trabajo normal de cada persona en su área.
-- "apoyo": tarea que un jefe publica para que ayude alguien de otra área.
--   Ciclo: publicada → asignada → en_curso (aceptada) → en_revision → aprobada.

create table public.tareas (
  id bigserial primary key,
  titulo text not null,
  descripcion text,
  tipo text not null check (tipo in ('regular', 'apoyo')),
  -- En una tarea de apoyo, el área que pide ayuda. En una regular, el área de quien la hace.
  area_id integer not null references public.areas (id),
  creada_por uuid not null references public.perfiles (id),
  asignada_a uuid references public.perfiles (id),
  estado text not null check (
    estado in ('publicada', 'asignada', 'en_curso', 'en_revision', 'aprobada', 'cancelada')
  ),
  horas_estimadas numeric(4, 1) not null check (horas_estimadas > 0),
  creada_en timestamptz not null default now(),
  asignada_en timestamptz,
  aceptada_en timestamptz,
  terminada_en timestamptz,
  aprobada_en timestamptz,
  origen text not null default 'real' check (origen in ('real', 'ejemplo')),
  check (estado in ('publicada', 'cancelada') or asignada_a is not null)
);

-- Habilidades que pide cada tarea (sirven para recomendar a quién asignarla).
create table public.tarea_habilidades (
  tarea_id bigint not null references public.tareas (id) on delete cascade,
  habilidad_id integer not null references public.habilidades (id),
  primary key (tarea_id, habilidad_id)
);

-- Cuando alguien rechaza una tarea de apoyo, queda el motivo.
create table public.tarea_rechazos (
  id bigserial primary key,
  tarea_id bigint not null references public.tareas (id) on delete cascade,
  perfil_id uuid not null references public.perfiles (id),
  motivo text,
  creado_en timestamptz not null default now()
);

alter table public.tareas enable row level security;
alter table public.tarea_habilidades enable row level security;
alter table public.tarea_rechazos enable row level security;

-- Una tarea la ven: quien la hace, quien la publicó, el jefe de su área y RR.HH.
-- Nadie más ve las tareas "publicadas" sin asignar: la disponibilidad es confidencial.
-- (Publicar, aceptar, rechazar y aprobar se activan en la Fase 4.)
create policy "ver mis tareas" on public.tareas
  for select to authenticated
  using (
    asignada_a = auth.uid()
    or creada_por = auth.uid()
    or public.mi_rol() = 'rh'
    or (public.mi_rol() = 'jefe' and area_id = public.mi_area())
  );

create policy "ver habilidades de mis tareas" on public.tarea_habilidades
  for select to authenticated
  using (exists (select 1 from public.tareas t where t.id = tarea_id));

create policy "ver rechazos de mis tareas" on public.tarea_rechazos
  for select to authenticated
  using (
    perfil_id = auth.uid()
    or public.mi_rol() = 'rh'
    or exists (select 1 from public.tareas t where t.id = tarea_id and t.creada_por = auth.uid())
  );
