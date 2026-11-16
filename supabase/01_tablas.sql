-- TalentoActivo · Fase 2 · Paso 1: tablas y reglas de privacidad
-- Se ejecuta una sola vez en Supabase > SQL Editor.

-- ============ TABLAS ============

-- Áreas de la consultora (Consumer Insights, Cuentas, etc.)
create table public.areas (
  id serial primary key,
  nombre text not null unique
);

-- Lista ordenada de habilidades (para evitar errores al escribir)
create table public.habilidades (
  id serial primary key,
  nombre text not null unique
);

-- Una fila por persona. El "id" es el mismo de su usuario para iniciar sesión.
create table public.perfiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nombre text not null,
  cargo text not null,
  area_id integer references public.areas (id),
  rol text not null check (rol in ('empleado', 'jefe', 'rh')),
  es_pasante boolean not null default false
);

-- Habilidades de cada persona, con su nivel
create table public.perfil_habilidades (
  perfil_id uuid not null references public.perfiles (id) on delete cascade,
  habilidad_id integer not null references public.habilidades (id),
  nivel text not null check (nivel in ('basico', 'intermedio', 'avanzado')),
  primary key (perfil_id, habilidad_id)
);

-- ============ PRIVACIDAD (RLS) ============
-- Con esto activado, nadie ve nada si no hay una regla que lo permita.

alter table public.areas enable row level security;
alter table public.habilidades enable row level security;
alter table public.perfiles enable row level security;
alter table public.perfil_habilidades enable row level security;

-- Función auxiliar: devuelve el rol de quien tiene la sesión iniciada.
create function public.mi_rol()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select rol from public.perfiles where id = auth.uid()
$$;

-- Áreas y lista de habilidades: las ve cualquier persona que haya iniciado sesión.
create policy "ver areas" on public.areas
  for select to authenticated using (true);

create policy "ver habilidades" on public.habilidades
  for select to authenticated using (true);

-- Perfiles (nombre, cargo, área, rol): los ve cualquier persona con sesión iniciada,
-- para poder mostrar quién pide una tarea. No contienen datos de disponibilidad.
create policy "ver perfiles" on public.perfiles
  for select to authenticated using (true);

-- Habilidades de cada persona: solo las ve la propia persona y Recursos Humanos.
-- (Los jefes las usarán más adelante solo a través de las recomendaciones.)
create policy "ver mis habilidades o RH" on public.perfil_habilidades
  for select to authenticated
  using (perfil_id = auth.uid() or public.mi_rol() = 'rh');
