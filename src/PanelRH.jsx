import { useEffect, useState } from 'react'
import { supabase } from './supabaseClient'
import { plural } from './tareasComunes'

const SEMAFORO = {
  rojo: { icono: '🔴', texto: 'Sobrecargada' },
  naranja: { icono: '🟠', texto: 'Capacidad libre' },
  verde: { icono: '🟢', texto: 'Equilibrada' },
}

const SUGERENCIAS = [
  '¿Qué área tiene mayor sobrecarga y a quién recomiendas mover para ayudar?',
  'Resume los riesgos actuales de tareas atrasadas y pedidos sin asignar.',
  'Redacta un mensaje breve y amable para pedir apoyo a una persona disponible.',
]

// Panel de carga de Recursos Humanos: semáforo por área, personas disponibles y asistente de IA.
function PanelRH() {
  const [areas, setAreas] = useState(null)
  const [disponibles, setDisponibles] = useState([])
  const [error, setError] = useState('')

  const [pregunta, setPregunta] = useState('')
  const [respuestaIA, setRespuestaIA] = useState('')
  const [cargandoIA, setCargandoIA] = useState(false)
  const [errorIA, setErrorIA] = useState('')

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

  async function consultarIA(textoConsulta) {
    const consulta = (textoConsulta ?? pregunta).trim()
    if (!consulta || cargandoIA) return

    setPregunta(consulta)
    setCargandoIA(true)
    setErrorIA('')
    setRespuestaIA('')

    const { data, error: fnError } = await supabase.functions.invoke('asistente-rh', {
      body: { pregunta: consulta, areas, disponibles },
    })

    setCargandoIA(false)

    if (fnError || data?.error) {
      setErrorIA(data?.error || 'No se pudo conectar con el asistente de IA. Intenta de nuevo.')
      return
    }

    setRespuestaIA(data.respuesta)
  }

  if (areas === null) return null

  const alertas = areas
    .filter((a) => a.semaforo === 'rojo')
    .map((a) => {
      const partes = []
      if (a.atrasadas > 0) partes.push(`${a.atrasadas} ${plural(a.atrasadas, 'tarea atrasada', 'tareas atrasadas')}`)
      if (a.promedio >= 85) partes.push(`actividad promedio de ${a.promedio} %`)
      if (a.apoyo_sin_asignar > 0)
        partes.push(
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

      <section className="inicio-bloque">
        <h2>Asistente de IA para RR.HH.</h2>
        <p className="texto-suave">
          Consulta sobre la carga actual de las áreas, riesgos de atraso o recomendaciones para reasignar personal disponible.
        </p>

        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.5rem', marginBottom: '0.75rem' }}>
          {SUGERENCIAS.map((s) => (
            <button
              key={s}
              type="button"
              onClick={() => consultarIA(s)}
              disabled={cargandoIA}
              style={{
                background: '#f1f5f9',
                color: '#0f172a',
                border: '1px solid #cbd5e1',
                borderRadius: '6px',
                padding: '0.4rem 0.7rem',
                fontSize: '0.85rem',
                cursor: 'pointer',
              }}
            >
              {s}
            </button>
          ))}
        </div>

        <form
          onSubmit={(e) => {
            e.preventDefault()
            consultarIA()
          }}
          style={{ display: 'flex', gap: '0.5rem', marginBottom: '0.75rem' }}
        >
          <input
            type="text"
            value={pregunta}
            onChange={(e) => setPregunta(e.target.value)}
            placeholder="Escribe tu consulta para el asistente..."
            disabled={cargandoIA}
            style={{
              flex: 1,
              padding: '0.55rem 0.75rem',
              borderRadius: '6px',
              border: '1px solid #cbd5e1',
              fontSize: '0.95rem',
            }}
          />
          <button
            type="submit"
            disabled={cargandoIA || !pregunta.trim()}
            style={{
              background: '#e67e22',
              color: '#fff',
              border: 'none',
              borderRadius: '6px',
              padding: '0.55rem 1rem',
              fontWeight: '600',
              cursor: 'pointer',
            }}
          >
            {cargandoIA ? 'Analizando...' : 'Consultar'}
          </button>
        </form>

        {errorIA && <p className="aviso-error">{errorIA}</p>}

        {respuestaIA && (
          <div
            style={{
              background: '#f8fafc',
              border: '1px solid #e2e8f0',
              borderRadius: '8px',
              padding: '1rem',
              whiteSpace: 'pre-wrap',
              lineHeight: '1.5',
            }}
          >
            {respuestaIA}
          </div>
        )}
      </section>
    </>
  )
}

export default PanelRH