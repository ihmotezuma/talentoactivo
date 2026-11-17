import { useState } from 'react'
import { PUNTOS_POLITICA } from './textoPolitica'

// Pantalla corta con la política de uso. Para aceptarla hay que marcar la casilla.
function Politica({ onAceptar, onCancelar, guardando, error }) {
  const [leida, setLeida] = useState(false)

  return (
    <div className="politica">
      <h2>Política de uso del monitoreo</h2>
      <p className="texto-suave">
        Antes de descargar el programa, lee esto con calma. Son seis puntos.
      </p>

      <dl className="politica-puntos">
        {PUNTOS_POLITICA.map((p) => (
          <div key={p.titulo}>
            <dt>{p.titulo}</dt>
            <dd>{p.texto}</dd>
          </div>
        ))}
      </dl>

      <label className="politica-casilla">
        <input
          type="checkbox"
          checked={leida}
          onChange={(e) => setLeida(e.target.checked)}
        />
        <span>He leído la política y la acepto.</span>
      </label>

      {error && <p className="login-error">{error}</p>}

      <div className="politica-botones">
        <button
          type="button"
          className="boton"
          disabled={!leida || guardando}
          onClick={onAceptar}
        >
          {guardando ? 'Guardando…' : 'Aceptar'}
        </button>
        <button type="button" className="enlace" onClick={onCancelar}>
          Ahora no
        </button>
      </div>
    </div>
  )
}

export default Politica
