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
          <a className="boton" href="/TalentoActivo-Mac.zip" download>
            Descargar para Mac
          </a>
          <ol className="pasos-instalacion">
            <li>Abre el archivo descargado y arrastra <b>TalentoActivo</b> a la carpeta Aplicaciones.</li>
            <li>
              Ábrelo desde Aplicaciones. La primera vez, macOS avisará que no puede verificar al
              desarrollador: entra en Ajustes del Sistema, Privacidad y seguridad, y pulsa
              «Abrir de todos modos».
            </li>
            <li>
              Inicia sesión con tu correo y contraseña de TalentoActivo. Verás <b>TA ●</b> en la barra
              superior: desde ahí puedes pausarlo o desinstalarlo cuando quieras.
            </li>
          </ol>
          <p className="texto-suave monitoreo-aviso">Para Mac con macOS 12 o más reciente.</p>
        </>
      )}
    </section>
  )
}

export default Monitoreo
