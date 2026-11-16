import './App.css'

const pasos = [
  {
    titulo: 'Marca tu disponibilidad',
    texto:
      'Si tienes una semana floja, avisa cuántas horas libres tienes. Es confidencial y puedes quitarlo cuando quieras.',
  },
  {
    titulo: 'Las áreas piden apoyo',
    texto:
      'Los jefes de las áreas con mucho trabajo publican tareas de apoyo con su habilidad, horas y fecha límite.',
  },
  {
    titulo: 'Recomendación clara',
    texto:
      'El sistema sugiere a quién puede ayudar y explica por qué: habilidad, horas libres y carga de la semana.',
  },
  {
    titulo: 'Se aprueba y se registra',
    texto:
      'Al terminar, quien pidió la tarea la aprueba. Queda registrado quién trabajó, sin vigilar a nadie.',
  },
]

function Persona({ x, y, color }) {
  return (
    <g transform={`translate(${x} ${y})`}>
      <circle cx="0" cy="-9" r="7" fill="#ffffff" />
      <path d="M-12 12 a12 12 0 0 1 24 0 z" fill="#ffffff" />
      <circle cx="17" cy="-14" r="5" fill={color} stroke="#0b2545" strokeWidth="1.5" />
    </g>
  )
}

function Ilustracion() {
  return (
    <svg
      className="ilustracion"
      viewBox="0 0 420 320"
      role="img"
      aria-label="Un área con mucho trabajo recibe ayuda de una persona libre de otra área"
    >
      {/* Área sobrecargada */}
      <rect x="250" y="20" width="160" height="130" rx="16" fill="#ffffff" fillOpacity="0.1" stroke="#ffffff" strokeOpacity="0.5" />
      <text x="330" y="46" textAnchor="middle" fill="#ffffff" fontSize="14" fontWeight="700">Cuentas</text>
      <Persona x={290} y={92} color="#f77f00" />
      <Persona x={350} y={92} color="#f77f00" />
      <rect x="270" y="122" width="120" height="10" rx="5" fill="#ffffff" fillOpacity="0.25" />
      <rect x="270" y="122" width="120" height="10" rx="5" fill="#f77f00" />

      {/* Área con tiempo libre */}
      <rect x="10" y="170" width="160" height="130" rx="16" fill="#ffffff" fillOpacity="0.1" stroke="#ffffff" strokeOpacity="0.5" />
      <text x="90" y="196" textAnchor="middle" fill="#ffffff" fontSize="14" fontWeight="700">Consumer Insights</text>
      <Persona x={50} y={242} color="#2e9e5b" />
      <Persona x={110} y={242} color="#d62839" />
      <rect x="30" y="272" width="120" height="10" rx="5" fill="#ffffff" fillOpacity="0.25" />
      <rect x="30" y="272" width="40" height="10" rx="5" fill="#d62839" />

      {/* Conexión de ayuda */}
      <path d="M126 242 C 240 242, 330 236, 330 164" fill="none" stroke="#f77f00" strokeWidth="3" strokeDasharray="7 6" strokeLinecap="round" />
      <path d="M322 168 L330 154 L338 168" fill="none" stroke="#f77f00" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />

      {/* Semáforo de carga */}
      <rect x="195" y="40" width="34" height="96" rx="12" fill="#0b2545" stroke="#ffffff" strokeOpacity="0.5" />
      <circle cx="212" cy="62" r="9" fill="#d62839" />
      <circle cx="212" cy="88" r="9" fill="#2e9e5b" />
      <circle cx="212" cy="114" r="9" fill="#f77f00" />
    </svg>
  )
}

function App() {
  return (
    <div className="pagina">
      <header className="cabecera">
        <div className="marca">
          <img src="/favicon.svg" alt="" />
          <span>
            Talento<b>Activo</b>
          </span>
        </div>
      </header>

      <main>
        <section className="portada">
          <div className="portada-contenido">
            <div className="portada-texto">
              <h1>
                Tu tiempo libre es la ayuda que <b>otra área necesita</b>
              </h1>
              <p>
                TalentoActivo conecta a las personas con semana floja con las
                áreas que están desbordadas, de forma confidencial y con
                criterio humano.
              </p>
              <button type="button" className="boton">
                Entrar
              </button>
              <span className="etiqueta">
                Consultora Delfos · Versión de demostración
              </span>
            </div>
            <Ilustracion />
          </div>
        </section>

        <section className="como">
          <h2>Cómo funciona</h2>
          <div className="pasos">
            {pasos.map((paso, i) => (
              <article className="paso" key={paso.titulo}>
                <span className="numero">{i + 1}</span>
                <h3>{paso.titulo}</h3>
                <p>{paso.texto}</p>
              </article>
            ))}
          </div>
        </section>
      </main>

      <footer className="pie">
        TalentoActivo · Proyecto final de Inteligencia Artificial · UCAB
      </footer>
    </div>
  )
}

export default App
