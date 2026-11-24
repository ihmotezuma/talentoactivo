import { useEffect, useState } from 'react'
import { supabase } from './supabaseClient'
import Monitoreo from './Monitoreo'
import MisApoyos from './MisApoyos'
import MiSemana from './MiSemana'
import PanelJefe from './PanelJefe'
import SemanaEquipo from './SemanaEquipo'
import PanelRH from './PanelRH'

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

const proximamente = {
  rh: ['Ver los números que demuestran que funciona (Fase 8)'],
}

function Inicio({ usuario }) {
  const [perfil, setPerfil] = useState(null)
  const [habilidades, setHabilidades] = useState([])
  const [problema, setProblema] = useState('')

  async function cargarHabilidades() {
    const { data: lista } = await supabase
      .from('perfil_habilidades')
      .select('nivel, habilidades(nombre)')
      .eq('perfil_id', usuario.id)
    setHabilidades(lista ?? [])
  }

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
  const pendientesRol = proximamente[perfil.rol] ?? []

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

      <Monitoreo usuario={usuario} />

      {perfil.rol === 'empleado' && (
        <>
          <MisApoyos usuario={usuario} />
          <MiSemana usuario={usuario} onHabilidadGanada={cargarHabilidades} />
        </>
      )}

      {perfil.rol === 'jefe' && (
        <>
          <PanelJefe usuario={usuario} />
          <SemanaEquipo />
        </>
      )}

      {perfil.rol === 'rh' && <PanelRH />}

      {pendientesRol.length > 0 && (
        <section className="inicio-bloque">
          <h2>Próximamente para ti</h2>
          <ul className="lista-proximamente">
            {pendientesRol.map((texto) => (
              <li key={texto}>{texto}</li>
            ))}
          </ul>
        </section>
      )}
    </main>
  )
}

export default Inicio
