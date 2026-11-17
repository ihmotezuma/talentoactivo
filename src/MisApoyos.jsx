import { useCallback, useEffect, useState } from 'react'
import { supabase } from './supabaseClient'
import { ETIQUETA_ESTADO, SELECCION_TAREA, plural } from './tareasComunes'

// Tarjeta del empleado: su disponibilidad y las tareas de apoyo que le asignaron.
function MisApoyos({ usuario }) {
  const [disp, setDisp] = useState(null)
  const [tareas, setTareas] = useState(null)
  const [regulares, setRegulares] = useState(0)
  const [rechazando, setRechazando] = useState(null) // id de la tarea que se rechaza
  const [motivo, setMotivo] = useState('')
  const [trabajando, setTrabajando] = useState(false)
  const [error, setError] = useState('')

  const cargar = useCallback(async () => {
    const [d, t] = await Promise.all([
      supabase.rpc('mi_disponibilidad').maybeSingle(),
      supabase
        .from('tareas')
        .select(SELECCION_TAREA)
        .eq('asignada_a', usuario.id)
        .in('estado', ['asignada', 'en_curso', 'en_revision'])
        .order('creada_en', { ascending: false }),
    ])
    setDisp(d.data ?? { disponible: false, porcentaje: null })
    if (t.error) {
      setError('No pudimos cargar tus tareas. Recarga la página en un momento.')
      setTareas([])
      return
    }
    const todas = t.data ?? []
    setTareas(todas.filter((x) => x.tipo === 'apoyo'))
    setRegulares(todas.filter((x) => x.tipo === 'regular' && x.estado !== 'en_revision').length)
  }, [usuario.id])

  useEffect(() => {
    cargar()
  }, [cargar])

  async function ejecutar(llamada) {
    setTrabajando(true)
    setError('')
    const { error: err } = await llamada
    setTrabajando(false)
    if (err) {
      setError(err.message)
    } else {
      setRechazando(null)
      setMotivo('')
    }
    cargar()
  }

  if (tareas === null) return null

  return (
    <section className="inicio-bloque">
      <h2>Tus tareas de apoyo</h2>

      {disp?.disponible ? (
        <p className="estado-disp estado-disp-si">
          ● Esta semana apareces como <b>disponible</b> para recibir tareas de apoyo. Solo tú ves
          esto ({disp.porcentaje} % de actividad en tus últimos días laborales).
        </p>
      ) : (
        <p className="estado-disp">
          ● Por ahora <b>no apareces como disponible</b>: tu actividad reciente está en un nivel
          normal. Nadie más ve esta información.
        </p>
      )}

      {regulares > 0 && (
        <p className="texto-suave">Además tienes {regulares} {plural(regulares, 'tarea regular abierta', 'tareas regulares abiertas')} en tu área.</p>
      )}

      {error && <p className="aviso-error">{error}</p>}

      {tareas.length === 0 ? (
        <p className="texto-suave">No tienes tareas de apoyo por ahora.</p>
      ) : (
        <ul className="tareas">
          {tareas.map((t) => (
            <li key={t.id} className="tarea">
              <div className="tarea-cabeza">
                <b>{t.titulo}</b>
                <span className={`etiqueta-estado estado-${t.estado}`}>{ETIQUETA_ESTADO[t.estado]}</span>
              </div>
              <p className="texto-suave">
                Pide: {t.creador?.nombre} · {t.area?.nombre} · {t.horas_estimadas} h estimadas
              </p>
              {t.descripcion && <p>{t.descripcion}</p>}

              {t.estado === 'asignada' && rechazando !== t.id && (
                <div className="acciones">
                  <button
                    type="button"
                    className="boton boton-chico"
                    disabled={trabajando}
                    onClick={() => ejecutar(supabase.rpc('responder_apoyo', { p_tarea: t.id, p_acepta: true }))}
                  >
                    Aceptar
                  </button>
                  <button
                    type="button"
                    className="boton-secundario"
                    disabled={trabajando}
                    onClick={() => setRechazando(t.id)}
                  >
                    Rechazar
                  </button>
                </div>
              )}

              {t.estado === 'asignada' && rechazando === t.id && (
                <div className="rechazo">
                  <label htmlFor={`motivo-${t.id}`}>¿Por qué no puedes? (opcional, lo ve quien publicó)</label>
                  <textarea
                    id={`motivo-${t.id}`}
                    value={motivo}
                    maxLength={300}
                    onChange={(e) => setMotivo(e.target.value)}
                  />
                  <div className="acciones">
                    <button
                      type="button"
                      className="boton boton-chico"
                      disabled={trabajando}
                      onClick={() =>
                        ejecutar(
                          supabase.rpc('responder_apoyo', { p_tarea: t.id, p_acepta: false, p_motivo: motivo }),
                        )
                      }
                    >
                      Confirmar rechazo
                    </button>
                    <button type="button" className="boton-secundario" onClick={() => setRechazando(null)}>
                      Cancelar
                    </button>
                  </div>
                </div>
              )}

              {t.estado === 'en_curso' && (
                <div className="acciones">
                  <button
                    type="button"
                    className="boton boton-chico"
                    disabled={trabajando}
                    onClick={() => ejecutar(supabase.rpc('terminar_tarea', { p_tarea: t.id }))}
                  >
                    Marcar como terminada
                  </button>
                </div>
              )}

              {t.estado === 'en_revision' && (
                <p className="texto-suave">Esperando que quien la pidió la apruebe.</p>
              )}
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}

export default MisApoyos
