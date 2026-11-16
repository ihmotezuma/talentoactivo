import { useEffect, useState } from 'react'
import { supabase } from './supabaseClient'
import Portada from './Portada'
import Login from './Login'
import Inicio from './Inicio'
import './App.css'

function App() {
  // undefined = todavía comprobando si hay una sesión iniciada
  const [sesion, setSesion] = useState(undefined)
  const [vista, setVista] = useState('portada')

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSesion(data.session))
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_evento, nuevaSesion) => {
      setSesion(nuevaSesion)
    })
    return () => subscription.unsubscribe()
  }, [])

  async function salir() {
    await supabase.auth.signOut()
    setVista('portada')
  }

  let contenido
  if (sesion === undefined) {
    contenido = <p className="cargando">Cargando…</p>
  } else if (sesion) {
    contenido = <Inicio usuario={sesion.user} />
  } else if (vista === 'login') {
    contenido = <Login onVolver={() => setVista('portada')} />
  } else {
    contenido = <Portada onEntrar={() => setVista('login')} />
  }

  return (
    <div className="pagina">
      <header className="cabecera">
        <div className="cabecera-interior">
          <button
            type="button"
            className="marca marca-boton"
            onClick={() => setVista('portada')}
          >
            <img src="/favicon.svg" alt="" />
            <span>
              Talento<b>Activo</b>
            </span>
          </button>
          {sesion && (
            <button type="button" className="boton-salir" onClick={salir}>
              Salir
            </button>
          )}
        </div>
      </header>

      {contenido}

      <footer className="pie">
        TalentoActivo · Proyecto final de Inteligencia Artificial · UCAB
      </footer>
    </div>
  )
}

export default App
