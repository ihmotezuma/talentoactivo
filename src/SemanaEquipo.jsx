import { useEffect, useState } from 'react'
import { supabase } from './supabaseClient'

function SemanaEquipo() {
  const [datos, setDatos] = useState(null)

  useEffect(() => {
    let activo = true
    async function cargar() {
      const { data, error } = await supabase.rpc('semana_equipo')
      if (!activo || error) return
      setDatos(data)
    }
    cargar()
    return () => {
      activo = false
    }
  }, [])

  if (!datos) return null

  const { resumen, apoyos } = datos

  return (
    <section className="inicio-bloque">
      <h2>Semana de mi equipo</h2>
      <p className="texto-suave">
        Avance semanal de entregas en tu área y habilidades desarrolladas por quienes te apoyaron.
      </p>

      <div className="semana-metricas">
        <div className="semana-tarjeta">
          <span className="texto-suave">Tareas aprobadas</span>
          <span className="semana-tarjeta-valor">{resumen.aprobadas}</span>
        </div>
        <div className="semana-tarjeta">
          <span className="texto-suave">Tareas en curso</span>
          <span className="semana-tarjeta-valor">{resumen.en_curso}</span>
        </div>
        <div className="semana-tarjeta">
          <span className="texto-suave">Horas entregadas</span>
          <span className="semana-tarjeta-valor">{resumen.horas_aprobadas} h</span>
        </div>
      </div>

      <h3 className="semana-subtitulo">Habilidades ganadas por quienes te ayudaron</h3>
      {apoyos.length === 0 ? (
        <p className="texto-suave">Aún no hay tareas de apoyo aprobadas en tu área.</p>
      ) : (
        <ul className="tareas">
          {apoyos.map((a) => (
            <li key={a.id} className="tarea">
              <div className="tarea-cabeza">
                <b>{a.colaborador}</b>
                <span className="puntaje">{a.horas_estimadas} h de apoyo</span>
              </div>
              <p className="texto-suave">
                Área de origen: {a.area_origen} · Tarea: «{a.titulo}»
              </p>
              {a.habilidades?.length > 0 && (
                <div className="chips-habilidades">
                  {a.habilidades.map((h) => (
                    <span key={h} className="chip-habilidad">
                      ★ {h}
                    </span>
                  ))}
                </div>
              )}
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}

export default SemanaEquipo
