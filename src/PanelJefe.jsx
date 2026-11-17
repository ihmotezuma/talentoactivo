import { useCallback, useEffect, useState } from 'react'
import { supabase } from './supabaseClient'
import { ETIQUETA_ESTADO, SELECCION_TAREA } from './tareasComunes'

// Panel del jefe de área: publicar tareas de apoyo, ver a quién recomienda el sistema,
// asignar y aprobar lo terminado.
function PanelJefe({ usuario }) {
  const [tareas, setTareas] = useState(null)
  const [habilidades, setHabilidades] = useState([])
  const [escribiendo, setEscribiendo] = useState(false)
  const [recomendando, setRecomendando] = useState(null) // { id, lista } | { id, cargando }
  const [trabajando, setTrabajando] = useState(false)
  const [error, setError] = useState('')

  const cargar = useCallback(async () => {
    const { data, error: err } = await supabase
      .from('tareas')
      .select(SELECCION_TAREA)
      .eq('creada_por', usuario.id)
      .in('estado', ['publicada', 'asignada', 'en_curso', 'en_revision'])
      .order('creada_en', { ascending: false })
    if (err) {
      setError('No pudimos cargar tus tareas. Recarga la página en un momento.')
      setTareas([])
      return
    }
    setTareas(data ?? [])
  }, [usuario.id])

  useEffect(() => {
    cargar()
    supabase
      .from('habilidades')
      .select('id, nombre')
      .order('nombre')
      .then(({ data }) => setHabilidades(data ?? []))
  }, [cargar])

  async function ejecutar(llamada) {
    setTrabajando(true)
    setError('')
    const { error: err } = await llamada
    setTrabajando(false)
    if (err) setError(err.message)
    setRecomendando(null)
    await cargar()
  }

  async function verRecomendaciones(id) {
    setError('')
    setRecomendando({ id, cargando: true })
    const { data, error: err } = await supabase.rpc('recomendar_candidatos', { p_tarea: id })
    if (err) {
      setError(err.message)
      setRecomendando(null)
      return
    }
    setRecomendando({ id, lista: data ?? [] })
  }

  if (tareas === null) return null

  // Nadie se aprueba a sí mismo: las tareas que hizo el propio jefe no aparecen aquí.
  const porAprobar = tareas.filter((t) => t.estado === 'en_revision' && t.asignado_a_id !== usuario.id)
  const apoyos = tareas.filter((t) => t.tipo === 'apoyo' && t.estado !== 'en_revision')

  return (
    <>
      {porAprobar.length > 0 && (
        <section className="inicio-bloque">
          <h2>Tareas por aprobar</h2>
          <ul className="tareas">
            {porAprobar.map((t) => (
              <li key={t.id} className="tarea">
                <div className="tarea-cabeza">
                  <b>{t.titulo}</b>
                  <span>
                    {t.tipo === 'apoyo' && <span className="etiqueta-estado etiqueta-apoyo">Apoyo de otra área</span>}{' '}
                    <span className="etiqueta-estado estado-en_revision">Terminada</span>
                  </span>
                </div>
                <p className="texto-suave">
                  Hecha por {t.asignado?.nombre} · {t.horas_estimadas} h estimadas
                </p>
                <div className="acciones">
                  <button
                    type="button"
                    className="boton boton-chico"
                    disabled={trabajando}
                    onClick={() => ejecutar(supabase.rpc('aprobar_tarea', { p_tarea: t.id }))}
                  >
                    Aprobar
                  </button>
                </div>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="inicio-bloque">
        <h2>Tareas de apoyo que pediste</h2>
        {error && <p className="aviso-error">{error}</p>}

        {!escribiendo && (
          <button type="button" className="boton boton-chico" onClick={() => setEscribiendo(true)}>
            + Publicar tarea de apoyo
          </button>
        )}
        {escribiendo && (
          <FormularioApoyo
            habilidades={habilidades}
            onCancelar={() => setEscribiendo(false)}
            onPublicada={async () => {
              setEscribiendo(false)
              await cargar()
            }}
          />
        )}

        {apoyos.length === 0 ? (
          <p className="texto-suave">No tienes tareas de apoyo abiertas.</p>
        ) : (
          <ul className="tareas">
            {apoyos.map((t) => (
              <li key={t.id} className="tarea">
                <div className="tarea-cabeza">
                  <b>{t.titulo}</b>
                  <span className={`etiqueta-estado estado-${t.estado}`}>{ETIQUETA_ESTADO[t.estado]}</span>
                </div>
                <p className="texto-suave">
                  {t.horas_estimadas} h estimadas
                  {t.asignado && <> · Asignada a {t.asignado.nombre}</>}
                </p>
                {t.tarea_habilidades.length > 0 && (
                  <p className="texto-suave">
                    Pide: {t.tarea_habilidades.map((x) => x.habilidades.nombre).join(', ')}
                  </p>
                )}

                {t.estado === 'publicada' && recomendando?.id !== t.id && (
                  <div className="acciones">
                    <button
                      type="button"
                      className="boton boton-chico"
                      onClick={() => verRecomendaciones(t.id)}
                    >
                      Ver recomendaciones
                    </button>
                    <button
                      type="button"
                      className="boton-secundario"
                      disabled={trabajando}
                      onClick={() => ejecutar(supabase.rpc('cancelar_apoyo', { p_tarea: t.id }))}
                    >
                      Cancelar tarea
                    </button>
                  </div>
                )}

                {t.estado === 'asignada' && (
                  <div className="acciones">
                    <button
                      type="button"
                      className="boton-secundario"
                      disabled={trabajando}
                      onClick={() => ejecutar(supabase.rpc('cancelar_apoyo', { p_tarea: t.id }))}
                    >
                      Cancelar tarea
                    </button>
                  </div>
                )}

                {recomendando?.id === t.id && (
                  <div className="recomendaciones">
                    {recomendando.cargando ? (
                      <p className="texto-suave">Buscando a las mejores personas…</p>
                    ) : recomendando.lista.length === 0 ? (
                      <p className="texto-suave">
                        Hoy no hay nadie disponible con esas habilidades en otras áreas. Puedes
                        intentarlo otro día o pedir menos habilidades.
                      </p>
                    ) : (
                      <ol>
                        {recomendando.lista.map((c) => (
                          <li key={c.perfil_id} className="candidato">
                            <div className="tarea-cabeza">
                              <b>{c.nombre}</b>
                              <span className="puntaje">{c.puntaje}/100</span>
                            </div>
                            <p className="texto-suave">
                              {c.cargo} · {c.area}
                            </p>
                            <ul className="motivos">
                              {c.motivos.map((m) => (
                                <li key={m}>{m}</li>
                              ))}
                            </ul>
                            <button
                              type="button"
                              className="boton boton-chico"
                              disabled={trabajando}
                              onClick={() =>
                                ejecutar(
                                  supabase.rpc('asignar_apoyo', { p_tarea: t.id, p_perfil: c.perfil_id }),
                                )
                              }
                            >
                              Asignar a {c.nombre.split(' ')[0]}
                            </button>
                          </li>
                        ))}
                      </ol>
                    )}
                    <button type="button" className="boton-secundario" onClick={() => setRecomendando(null)}>
                      Cerrar
                    </button>
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>
    </>
  )
}

function FormularioApoyo({ habilidades, onCancelar, onPublicada }) {
  const [titulo, setTitulo] = useState('')
  const [descripcion, setDescripcion] = useState('')
  const [horas, setHoras] = useState('4')
  const [elegidas, setElegidas] = useState([])
  const [enviando, setEnviando] = useState(false)
  const [error, setError] = useState('')

  function alternar(id) {
    setElegidas((actual) => (actual.includes(id) ? actual.filter((x) => x !== id) : [...actual, id]))
  }

  async function enviar(e) {
    e.preventDefault()
    setEnviando(true)
    setError('')
    const { error: err } = await supabase.rpc('publicar_apoyo', {
      p_titulo: titulo,
      p_descripcion: descripcion,
      p_horas: Number(horas.replace(',', '.')),
      p_habilidades: elegidas,
    })
    setEnviando(false)
    if (err) {
      setError(err.message)
      return
    }
    onPublicada()
  }

  return (
    <form className="formulario-apoyo" onSubmit={enviar}>
      <label htmlFor="ap-titulo">Título</label>
      <input id="ap-titulo" value={titulo} maxLength={120} onChange={(e) => setTitulo(e.target.value)} required />

      <label htmlFor="ap-desc">Qué hay que hacer</label>
      <textarea id="ap-desc" value={descripcion} maxLength={500} onChange={(e) => setDescripcion(e.target.value)} />

      <label htmlFor="ap-horas">Horas estimadas</label>
      <input
        id="ap-horas"
        inputMode="decimal"
        value={horas}
        onChange={(e) => setHoras(e.target.value)}
        required
      />

      <fieldset>
        <legend>Habilidades que se necesitan</legend>
        <div className="habilidades-elegir">
          {habilidades.map((h) => (
            <label key={h.id} className="casilla">
              <input type="checkbox" checked={elegidas.includes(h.id)} onChange={() => alternar(h.id)} />
              {h.nombre}
            </label>
          ))}
        </div>
      </fieldset>

      {error && <p className="aviso-error">{error}</p>}
      <div className="acciones">
        <button type="submit" className="boton boton-chico" disabled={enviando}>
          {enviando ? 'Publicando…' : 'Publicar'}
        </button>
        <button type="button" className="boton-secundario" onClick={onCancelar}>
          Cancelar
        </button>
      </div>
    </form>
  )
}

export default PanelJefe
