import { useEffect, useState } from 'react'
import { supabase } from './supabaseClient'
import { plural } from './tareasComunes'

const SEMAFORO = {
  rojo: { icono: '🔴', texto: 'Sobrecargada' },
  naranja: { icono: '🟠', texto: 'Capacidad libre' },
  verde: { icono: '🟢', texto: 'Equilibrada' },
}

// Panel de carga de Recursos Humanos: semáforo por área, alertas y personas disponibles.
function PanelRH() {
  const [areas, setAreas] = useState(null)
  const [disponibles, setDisponibles] = useState([])
  const [error, setError] = useState('')

  useEffect(() => {
    let activo = true
    async function cargar() {
      const [a, d] = await Promise.all([supabase.rpc('panel_carga'), supabase.rpc('personas_disponibles')])
      if (!activo) return
      if (a.error || d.error) {
        setError('No pudimos cargar el panel de carga. Recarga la página en un momento.')
        setAreas([])
        return
      }
      setAreas(a.data ?? [])
      setDisponibles(d.data ?? [])
    }
    cargar()
    return () => {
      activo = false
    }
  }, [])

  if (areas === null) return null

  const alertas = areas
    .filter((a) => a.semaforo === 'rojo')
    .map((a) => {
      const partes = []
      if (a.atrasadas > 0) partes.push(`${a.atrasadas} ${plural(a.atrasadas, 'tarea atrasada', 'tareas atrasadas')}`)
      if (a.promedio >= 85) partes.push(`actividad promedio de ${a.promedio} %`)
      if (a.apoyo_sin_asignar > 0) partes.push(
          `${a.apoyo_sin_asignar} ${plural(a.apoyo_sin_asignar, 'pedido de apoyo sin asignar', 'pedidos de apoyo sin asignar')}`,
        )
      return `${a.area}: ${partes.join(', ')}.`
    })

  return (
    <>
      <section className="inicio-bloque">
        <h2>Panel de carga por área</h2>
        {error && <p className="aviso-error">{error}</p>}

        {alertas.length > 0 && (
          <div className="alertas">
            <b>Alertas</b>
            <ul>
              {alertas.map((t) => (
                <li key={t}>{t}</li>
              ))}
            </ul>
            {disponibles.length > 0 && (
              <p>
                Hay {disponibles.length}{' '}
                {plural(disponibles.length, 'persona disponible que podría ayudar', 'personas disponibles que podrían ayudar')}{' '}
                (ver abajo).
              </p>
            )}
          </div>
        )}

        <div className="tabla-envoltorio">
          <table className="tabla-carga">
            <thead>
              <tr>
                <th>Área</th>
                <th>Estado</th>
                <th>Actividad prom.</th>
                <th>Personas</th>
                <th>Disponibles</th>
                <th>Tareas abiertas</th>
                <th>Atrasadas</th>
                <th>Apoyo sin asignar</th>
              </tr>
            </thead>
            <tbody>
              {areas.map((a) => (
                <tr key={a.area}>
                  <td>{a.area}</td>
                  <td>
                    <span aria-hidden="true">{SEMAFORO[a.semaforo].icono}</span> {SEMAFORO[a.semaforo].texto}
                  </td>
                  <td>{a.promedio == null ? '—' : `${a.promedio} %`}</td>
                  <td>{a.personas}</td>
                  <td>{a.disponibles}</td>
                  <td>{a.abiertas}</td>
                  <td>{a.atrasadas}</td>
                  <td>{a.apoyo_sin_asignar}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="texto-suave">
          🔴 actividad promedio de 85 % o más, o 3+ tareas atrasadas · 🟠 hay personas con menos de 40 %
          de actividad · 🟢 todo en equilibrio. Se mide con los últimos 3 días laborales completos.
        </p>
      </section>

      <section className="inicio-bloque">
        <h2>Personas disponibles</h2>
        {disponibles.length === 0 ? (
          <p className="texto-suave">Hoy nadie aparece como disponible.</p>
        ) : (
          <ul className="tareas">
            {disponibles.map((p) => (
              <li key={p.perfil_id} className="tarea">
                <div className="tarea-cabeza">
                  <b>{p.nombre}</b>
                  <span className="puntaje">{p.porcentaje} % activo</span>
                </div>
                <p className="texto-suave">
                  {p.cargo} · {p.area}
                </p>
                {p.habilidades?.length > 0 && <p className="texto-suave">Habilidades: {p.habilidades.join(', ')}</p>}
              </li>
            ))}
          </ul>
        )}
      </section>
    </>
  )
}

export default PanelRH
