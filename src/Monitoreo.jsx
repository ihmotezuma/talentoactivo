import { useEffect, useState } from 'react'
import { supabase } from './supabaseClient'
import { VERSION_POLITICA } from './textoPolitica'
import Politica from './Politica'

const formatoFecha = new Intl.DateTimeFormat('es', {
  dateStyle: 'long',
  timeStyle: 'short',
})

// Tarjeta "Monitoreo de actividad": consentimiento primero, descarga después.
function Monitoreo({ usuario }) {
  const [estado, setEstado] = useState('cargando') // cargando | pendiente | aceptado | error
  const [aceptadoEn, setAceptadoEn] = useState(null)
  const [leyendo, setLeyendo] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    let activo = true
    async function cargar() {
      const { data, error: err } = await supabase
        .from('consentimientos')
        .select('aceptado_en')
        .eq('perfil_id', usuario.id)
        .eq('version', VERSION_POLITICA)
        .maybeSingle()
      if (!activo) return
      if (err) {
        setEstado('error')
      } else if (data) {
        setAceptadoEn(data.aceptado_en)
        setEstado('aceptado')
      } else {
        setEstado('pendiente')
      }
    }
    cargar()
    return () => {
      activo = false
    }
  }, [usuario.id])

  async function aceptar() {
    setGuardando(true)
    setError('')
    const { error: err } = await supabase
      .from('consentimientos')
      .insert({ perfil_id: usuario.id, version: VERSION_POLITICA })
    setGuardando(false)
    // 23505 = ya la había aceptado (por ejemplo, doble clic): cuenta como aceptada.
    if (err && err.code !== '23505') {
      setError('No pudimos guardar tu aceptación. Inténtalo de nuevo.')
      return
    }
    setAceptadoEn(new Date().toISOString())
    setEstado('aceptado')
    setLeyendo(false)
  }

  if (leyendo) {
    return (
      <section className="inicio-bloque">
        <Politica
          onAceptar={aceptar}
          onCancelar={() => setLeyendo(false)}
          guardando={guardando}
          error={error}
        />
      </section>
    )
  }

  return (
    <section className="inicio-bloque">
      <h2>Monitoreo de actividad</h2>

      {estado === 'cargando' && <p className="texto-suave">Cargando…</p>}

      {estado === 'error' && (
        <p className="texto-suave">
          No pudimos revisar el estado de tu consentimiento. Recarga la página en un momento.
        </p>
      )}

      {estado === 'pendiente' && (
        <>
          <p>
            Un programa pequeño para tu computadora mide si estás activo o inactivo, para repartir
            mejor el trabajo. Nunca captura pantallas, teclas, correos ni páginas web.
          </p>
          <p className="texto-suave monitoreo-aviso">
            Antes de descargarlo, necesitas leer y aceptar la política de uso.
          </p>
          <button type="button" className="boton" onClick={() => setLeyendo(true)}>
            Leer y aceptar la política
          </button>
        </>
      )}

      {estado === 'aceptado' && (
        <>
          <p className="monitoreo-ok">
            ✓ Aceptaste la política el {formatoFecha.format(new Date(aceptadoEn))}.
          </p>
          <button type="button" className="boton" disabled>
            Descargar para Mac
          </button>
          <p className="texto-suave monitoreo-aviso">
            El programa estará disponible para descargar en la Fase 5.
          </p>
        </>
      )}
    </section>
  )
}

export default Monitoreo
