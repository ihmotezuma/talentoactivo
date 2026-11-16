-- TalentoActivo · Fase 2 · Paso 2: datos de ejemplo de la Consultora Delfos
-- Crea las áreas, las habilidades, los 14 usuarios de prueba y sus perfiles.
-- Se ejecuta UNA sola vez en Supabase > SQL Editor.
-- Todos los usuarios tienen la contraseña de demostración: Delfos2026!
-- (Son personas ficticias. No usar esa contraseña en ningún otro sitio.)

-- ============ ÁREAS ============
insert into public.areas (nombre) values
  ('Consumer Insights'),
  ('Trabajo de Campo'),
  ('Análisis de Datos'),
  ('Cuentas'),
  ('Recursos Humanos');

-- ============ HABILIDADES ============
insert into public.habilidades (nombre) values
  ('Redacción de informes'),
  ('Presentaciones'),
  ('Moderación de grupos focales'),
  ('Análisis cualitativo'),
  ('Trabajo de campo y encuestas'),
  ('Estadística'),
  ('Excel avanzado'),
  ('Visualización de datos'),
  ('Atención a clientes'),
  ('Gestión de proyectos'),
  ('Transcripción y codificación');

-- ============ USUARIOS Y PERFILES ============
do $$
declare
  p record;
  uid uuid;
begin
  for p in
    select * from (values
      ('carolina.rojas@delfos.example',      'Carolina Rojas',      'Gerente de RR.HH.',     'Recursos Humanos',  'rh',       false),
      ('andrea.villalobos@delfos.example',   'Andrea Villalobos',   'Jefa de área',          'Consumer Insights', 'jefe',     false),
      ('luis.gomez@delfos.example',          'Luis Gómez',          'Analista',              'Consumer Insights', 'empleado', false),
      ('valentina.rios@delfos.example',      'Valentina Ríos',      'Analista junior',       'Consumer Insights', 'empleado', false),
      ('maria.perez@delfos.example',         'María Pérez',         'Pasante',               'Consumer Insights', 'empleado', true),
      ('ricardo.mendoza@delfos.example',     'Ricardo Mendoza',     'Jefe de área',          'Trabajo de Campo',  'jefe',     false),
      ('daniela.castillo@delfos.example',    'Daniela Castillo',    'Supervisora de campo',  'Trabajo de Campo',  'empleado', false),
      ('joseangel.torres@delfos.example',    'José Ángel Torres',   'Pasante',               'Trabajo de Campo',  'empleado', true),
      ('gabriela.sanchez@delfos.example',    'Gabriela Sánchez',    'Jefa de área',          'Análisis de Datos', 'jefe',     false),
      ('miguel.herrera@delfos.example',      'Miguel Herrera',      'Analista',              'Análisis de Datos', 'empleado', false),
      ('sofia.navarro@delfos.example',       'Sofía Navarro',       'Pasante',               'Análisis de Datos', 'empleado', true),
      ('alejandro.fernandez@delfos.example', 'Alejandro Fernández', 'Jefe de área',          'Cuentas',           'jefe',     false),
      ('paola.marquez@delfos.example',       'Paola Márquez',       'Ejecutiva de cuentas',  'Cuentas',           'empleado', false),
      ('andres.colmenares@delfos.example',   'Andrés Colmenares',   'Ejecutivo de cuentas',  'Cuentas',           'empleado', false)
    ) as t(email, nombre, cargo, area, rol, pasante)
  loop
    uid := gen_random_uuid();

    -- Usuario para iniciar sesión (correo + contraseña)
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      email_change_token_current, phone_change, phone_change_token, reauthentication_token
    ) values (
      '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated',
      p.email, extensions.crypt('Delfos2026!', extensions.gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}', '{}', now(), now(),
      '', '', '', '', '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), uid, uid::text,
      jsonb_build_object('sub', uid::text, 'email', p.email, 'email_verified', true),
      'email', now(), now(), now()
    );

    -- Perfil dentro de TalentoActivo
    insert into public.perfiles (id, nombre, cargo, area_id, rol, es_pasante)
    values (uid, p.nombre, p.cargo, (select id from public.areas where nombre = p.area), p.rol, p.pasante);
  end loop;
end $$;

-- ============ HABILIDADES DE CADA PERSONA ============
insert into public.perfil_habilidades (perfil_id, habilidad_id, nivel)
select u.id, h.id, v.nivel
from (values
  ('carolina.rojas@delfos.example',      'Presentaciones',                'avanzado'),

  ('andrea.villalobos@delfos.example',   'Moderación de grupos focales',  'avanzado'),
  ('andrea.villalobos@delfos.example',   'Análisis cualitativo',          'avanzado'),
  ('andrea.villalobos@delfos.example',   'Presentaciones',                'avanzado'),

  ('luis.gomez@delfos.example',          'Análisis cualitativo',          'intermedio'),
  ('luis.gomez@delfos.example',          'Redacción de informes',         'intermedio'),
  ('luis.gomez@delfos.example',          'Transcripción y codificación',  'avanzado'),

  ('valentina.rios@delfos.example',      'Redacción de informes',         'basico'),
  ('valentina.rios@delfos.example',      'Presentaciones',                'intermedio'),
  ('valentina.rios@delfos.example',      'Transcripción y codificación',  'basico'),

  ('maria.perez@delfos.example',         'Redacción de informes',         'avanzado'),
  ('maria.perez@delfos.example',         'Análisis cualitativo',          'intermedio'),
  ('maria.perez@delfos.example',         'Transcripción y codificación',  'avanzado'),

  ('ricardo.mendoza@delfos.example',     'Trabajo de campo y encuestas',  'avanzado'),
  ('ricardo.mendoza@delfos.example',     'Gestión de proyectos',          'avanzado'),

  ('daniela.castillo@delfos.example',    'Trabajo de campo y encuestas',  'avanzado'),
  ('daniela.castillo@delfos.example',    'Transcripción y codificación',  'intermedio'),
  ('daniela.castillo@delfos.example',    'Atención a clientes',           'basico'),

  ('joseangel.torres@delfos.example',    'Trabajo de campo y encuestas',  'intermedio'),
  ('joseangel.torres@delfos.example',    'Excel avanzado',                'avanzado'),

  ('gabriela.sanchez@delfos.example',    'Estadística',                   'avanzado'),
  ('gabriela.sanchez@delfos.example',    'Visualización de datos',        'avanzado'),
  ('gabriela.sanchez@delfos.example',    'Excel avanzado',                'avanzado'),

  ('miguel.herrera@delfos.example',      'Estadística',                   'intermedio'),
  ('miguel.herrera@delfos.example',      'Excel avanzado',                'avanzado'),
  ('miguel.herrera@delfos.example',      'Visualización de datos',        'intermedio'),

  ('sofia.navarro@delfos.example',       'Excel avanzado',                'intermedio'),
  ('sofia.navarro@delfos.example',       'Visualización de datos',        'intermedio'),
  ('sofia.navarro@delfos.example',       'Redacción de informes',         'basico'),

  ('alejandro.fernandez@delfos.example', 'Atención a clientes',           'avanzado'),
  ('alejandro.fernandez@delfos.example', 'Gestión de proyectos',          'avanzado'),
  ('alejandro.fernandez@delfos.example', 'Presentaciones',                'avanzado'),

  ('paola.marquez@delfos.example',       'Atención a clientes',           'avanzado'),
  ('paola.marquez@delfos.example',       'Redacción de informes',         'intermedio'),
  ('paola.marquez@delfos.example',       'Presentaciones',                'intermedio'),

  ('andres.colmenares@delfos.example',   'Atención a clientes',           'intermedio'),
  ('andres.colmenares@delfos.example',   'Presentaciones',                'intermedio'),
  ('andres.colmenares@delfos.example',   'Excel avanzado',                'basico')
) as v(email, habilidad, nivel)
join auth.users u on u.email = v.email
join public.habilidades h on h.nombre = v.habilidad;
