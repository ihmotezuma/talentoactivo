import { useEffect, useState } from 'react'
import { supabase } from './supabaseClient'

const etiquetaRol = {
  empleado: 'Empleado',
  jefe: 'Jefe de área',
  rh: 'Recursos Humanos',
}

const etiquetaNivel = {
  basico: 'Básico',
  intermedio: 'Intermedio',
  avanzado: 'Avanzado',
}

// Lo que cada rol podrá hacer. Se irá activando en las próximas fases.
const proximamente = {
  empleado: [
    'Marcar que tienes horas libres, de forma confidencial (Fase 3)',
    'Recibir invitaciones a tareas de apoyo y aceptarlas o rechazarlas (Fase 5)',
  ],
  jefe: [
    'Publicar tareas de apoyo para tu área (Fase 4)',
    'Ver a las personas que el sistema recomienda y por qué (Fase 4)',
    'Aprobar las tareas terminadas (Fase 5)',
  ],
  rh: [
    'Ver el panel de carga de todas las áreas, con semáforo (Fase 6)',
    'Ver quién está disponible, con nombre, para apoyarle (Fase 6)',
  ],
}

function Inicio({ usuario }) {
  const [perfil, setPerfil] = useState(null)
  const [habilidades, setHabilidades] = useState([])
  const [problema, setProblema] = useState('')

  useEffect(() => {
    let activo = true
    async function cargar() {
      const { data, error } = await supabase
        .from('perfiles')
        .select('nombre, cargo, rol, es_pasante, areas(nombre)')
        .eq('id', usuario.id)
        .single()
      if (!activo) return
      if (error) {
        setProblema('No pudimos cargar tu perfil. Cierra sesión y vuelve a entrar.')
        return
      }
      setPerfil(data)

      const { data: lista } = await supabase
        .from('perfil_habilidades')
        .select('nivel, habilidades(nombre)')
        .eq('perfil_id', usuario.id)
      if (activo) setHabilidades(lista ?? [])
    }
    cargar()
    return () => {
      activo = false
    }
  }, [usuario.id])

  if (problema) return <p className="cargando">{problema}</p>
  if (!perfil) return <p className="cargando">Cargando…</p>

  const primerNombre = perfil.nombre.split(' ')[0]

  return (
    <main className="inicio">
      <section className="inicio-saludo">
        <h1>Hola, {primerNombre}</h1>
        <p>
          {perfil.cargo} · {perfil.areas?.nombre}
        </p>
        <span className="etiqueta-rol">{etiquetaRol[perfil.rol]}</span>
      </section>

      <section className="inicio-bloque">
        <h2>Tus habilidades</h2>
        {habilidades.length === 0 ? (
          <p className="texto-suave">Aún no hay habilidades registradas.</p>
        ) : (
          <ul className="habilidades">
            {habilidades.map((h) => (
              <li key={h.habilidades.nombre}>
                {h.habilidades.nombre}
                <span>{etiquetaNivel[h.nivel]}</span>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="inicio-bloque">
        <h2>Próximamente para ti</h2>
        <ul className="lista-proximamente">
          {proximamente[perfil.rol].map((texto) => (
            <li key={texto}>{texto}</li>
          ))}
        </ul>
      </section>
    </main>
  )
}

export default Inicio
