import { useEffect, useState } from 'react'
import { supabase } from './supabaseClient'

const ETIQUETA_ESTADO = {
  asignada: 'Por aceptar',
  en_curso: 'En curso',
  en_revision: 'En revisión',
  aprobada: 'Aprobada',
}

function inicioSemanaISO() {
  const ahora = new Date()
  const dia = ahora.getDay()
  const diff = ahora.getDate() - dia + (dia === 0 ? -6 : 1)
  const lunes = new Date(ahora.setDate(diff))
  lunes.setHours(0, 0, 0, 0)
  return lunes.toISOString()
}

function MiSemana({ usuario, onHabilidadGanada }) {
  const [cargando, setCargando] = useState(true)
  const [actividad, setActividad] = useState({ activos: 0, inactivos: 0 })
  const [tareas, setTareas] = useState([])
  const [habilidadesGanadas, setHabilidadesGanadas] = useState([])

  useEffect(() => {
    let activo = true
    async function cargar() {
      const desde = inicioSemanaISO()

      const [actRes, tarRes] = await Promise.all([
        supabase
          .from('actividad_bloques')
          .select('minutos_activos, minutos_inactivos')
          .eq('perfil_id', usuario.id)
          .gte('inicio', desde),
        supabase
          .from('tareas')
          .select('id, titulo, tipo, estado, horas_estimadas, aprobada_en, areas(nombre), tarea_habilidades(habilidades(nombre))')
          .eq('asignada_a', usuario.id)
          .neq('estado', 'cancelada')
          .order('creada_en', { ascending: false }),
      ])

      if (!activo) return

      const bloques = actRes.data ?? []
      const sumAct = bloques.reduce((acc, b) => acc + (b.minutos_activos || 0), 0)
      const sumInact = bloques.reduce((acc, b) => acc + (b.minutos_inactivos || 0), 0)
      setActividad({ activos: sumAct, inactivos: sumInact })

      const listaTareas = tarRes.data ?? []
      setTareas(listaTareas)

      const ganadasSet = new Set()
      listaTareas
        .filter((t) => t.tipo === 'apoyo' && t.estado === 'aprobada')
        .forEach((t) => {
          ;(t.tarea_habilidades ?? []).forEach((th) => {
            if (th.habilidades?.nombre) ganadasSet.add(th.habilidades.nombre)
          })
        })
      const ganadas = Array.from(ganadasSet)
      setHabilidadesGanadas(ganadas)
      if (ganadas.length > 0 && onHabilidadGanada) onHabilidadGanada()

      setCargando(false)
    }
    cargar()
    return () => {
      activo = false
    }
  }, [usuario.id])

  if (cargando) return null

  const horasActivas = (actividad.activos / 60).toFixed(1)
  const totalMin = actividad.activos + actividad.inactivos
  const porcentajeActivo = totalMin > 0 ? Math.round((actividad.activos * 100) / totalMin) : 0

  return (
    <section className="inicio-bloque">
      <h2>Mi semana</h2>
      <p className="texto-suave">Resumen confidencial de tu actividad, tareas y habilidades desarrolladas.</p>

      <div className="semana-metricas">
        <div className="semana-tarjeta">
          <span className="texto-suave">Tiempo activo</span>
          <span className="semana-tarjeta-valor">{horasActivas} h</span>
        </div>
        <div className="semana-tarjeta">
          <span className="texto-suave">Ritmo de actividad</span>
          <span className="semana-tarjeta-valor">{totalMin > 0 ? `${porcentajeActivo} %` : '—'}</span>
        </div>
        <div className="semana-tarjeta">
          <span className="texto-suave">Tareas registradas</span>
          <span className="semana-tarjeta-valor">{tareas.length}</span>
        </div>
      </div>

      <h3 className="semana-subtitulo">Habilidades ganadas en apoyos</h3>
      {habilidadesGanadas.length === 0 ? (
        <p className="texto-suave">
          Cuando completes y te aprueben una tarea de apoyo, las habilidades practicadas aparecerán aquí.
        </p>
      ) : (
        <div className="chips-habilidades">
          {habilidadesGanadas.map((h) => (
            <span key={h} className="chip-habilidad">
              ★ {h}
            </span>
          ))}
        </div>
      )}

      <h3 className="semana-subtitulo">Tus tareas</h3>
      {tareas.length === 0 ? (
        <p className="texto-suave">No tienes tareas asignadas esta semana.</p>
      ) : (
        <ul className="tareas">
          {tareas.map((t) => (
            <li key={t.id} className="tarea">
              <div className="tarea-cabeza">
                <b>{t.titulo}</b>
                <span className={`etiqueta-estado estado-${t.estado}`}>
                  {ETIQUETA_ESTADO[t.estado] ?? t.estado}
                </span>
              </div>
              <p className="texto-suave">
                {t.tipo === 'apoyo' ? `Apoyo para ${t.areas?.nombre ?? 'otra área'}` : 'Tarea regular'} ·{' '}
                {t.horas_estimadas} h estimadas
              </p>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}

export default MiSemana
