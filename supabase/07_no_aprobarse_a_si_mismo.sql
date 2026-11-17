-- TalentoActivo · Fase 4 · Parche: nadie puede aprobar su propia tarea
-- Se ejecuta UNA vez en Supabase > SQL Editor. Se puede repetir sin problema.

create or replace function public.aprobar_tarea(p_tarea bigint)
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
