import { useState } from 'react'
import { supabase } from './supabaseClient'

// Usuarios de la Consultora Delfos para la demostración (todos ficticios).
// Al tocar uno solo se escribe su correo; la contraseña la escribe quien hace la demo.
const usuariosDemo = [
  { nombre: 'María Pérez', detalle: 'Pasante · Consumer Insights', email: 'maria.perez@delfos.example' },
  { nombre: 'Alejandro Fernández', detalle: 'Jefe de área · Cuentas', email: 'alejandro.fernandez@delfos.example' },
  { nombre: 'Carolina Rojas', detalle: 'Recursos Humanos', email: 'carolina.rojas@delfos.example' },
]

function Login({ onVolver }) {
  const [email, setEmail] = useState('')
  const [clave, setClave] = useState('')
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(false)

  async function enviar(evento) {
    evento.preventDefault()
    setError('')
    setCargando(true)
    const { error: errorLogin } = await supabase.auth.signInWithPassword({
      email: email.trim(),
      password: clave,
    })
    setCargando(false)
    if (errorLogin) {
      setError('Correo o contraseña incorrectos. Revisa los datos e inténtalo de nuevo.')
    }
    // Si todo sale bien, la aplicación detecta la sesión y muestra el inicio.
  }

  return (
    <main className="login-pagina">
      <form className="login-tarjeta" onSubmit={enviar}>
        <h1>Entrar a TalentoActivo</h1>
        <p className="login-ayuda">Usa tu correo de la empresa y tu contraseña.</p>

        <label htmlFor="email">Correo</label>
        <input
          id="email"
          type="email"
          autoComplete="username"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />

        <label htmlFor="clave">Contraseña</label>
        <input
          id="clave"
          type="password"
          autoComplete="current-password"
          required
          value={clave}
          onChange={(e) => setClave(e.target.value)}
        />

        {error && (
          <p className="login-error" role="alert">
            {error}
          </p>
        )}

        <button type="submit" className="boton boton-ancho" disabled={cargando}>
          {cargando ? 'Entrando…' : 'Entrar'}
        </button>
        <button type="button" className="enlace" onClick={onVolver}>
          ← Volver a la portada
        </button>
      </form>

      <aside className="login-demo">
        <h2>Usuarios de demostración</h2>
        <p>Consultora Delfos · toca uno para escribir su correo.</p>
        <ul>
          {usuariosDemo.map((u) => (
            <li key={u.email}>
              <button type="button" onClick={() => setEmail(u.email)}>
                <strong>{u.nombre}</strong>
                <span>{u.detalle}</span>
              </button>
            </li>
          ))}
        </ul>
      </aside>
    </main>
  )
}

export default Login
