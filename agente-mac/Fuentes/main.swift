import AppKit

// Modo de comprobación: `TalentoActivo --autoprueba` revisa la lógica de los bloques
// de 5 minutos sin abrir ventanas ni conectarse a internet.
if CommandLine.arguments.contains("--autoprueba") {
  MainActor.assumeIsolated { Autoprueba.ejecutar() }
  exit(0)
}

MainActor.assumeIsolated {
  let app = NSApplication.shared
  let agente = Agente()
  app.delegate = agente
  app.setActivationPolicy(.accessory)  // sin ícono en el Dock: solo la barra superior
  app.run()
}
