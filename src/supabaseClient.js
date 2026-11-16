import { createClient } from '@supabase/supabase-js'

// La URL y la clave pública vienen del archivo .env (en Cloudflare, de sus variables).
// Esta clave es pública por diseño: la privacidad la protegen las reglas (RLS) de Supabase.
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY,
)
