import AppKit

enum Estado {
  case sinSesion
  case midiendo
  case pausado
  case sinPermiso  // falta aceptar la política vigente en la página web
}

@MainActor
final class Agente: NSObject, NSApplicationDelegate {
  private let nube = Nube()
  private let medidor = Medidor()
  private var estado: Estado = .sinSesion
  private var conexionCaida = false
  private var ultimoEnvio: Date?
  private var enviando = false
  private var noReintentarAntes = Date.distantPast
  private var temporizador: Timer?
  private var iniciandoSesion = false

  private let icono = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let lineaEstado = NSMenuItem()
  private let botonPausa = NSMenuItem()
  private let botonSesion = NSMenuItem()

  // MARK: Arranque

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard instaladoEnAplicaciones() else { return }
    construirMenu()
    estado = nube.haySesion ? .midiendo : .sinSesion
    actualizarMenu()
    if !nube.haySesion { Task { await iniciarSesionConDialogo(mensaje: nil) } }
    programarMinuto()
  }

  func applicationWillTerminate(_ notification: Notification) {
    medidor.cerrarActual()
  }

  // Si se abre desde Descargas, macOS lo ejecuta desde una ubicación temporal y no podría
  // arrancar solo al iniciar sesión. Por eso se pide moverlo a Aplicaciones.
  private func instaladoEnAplicaciones() -> Bool {
    if ProcessInfo.processInfo.environment["TA_DESARROLLO"] != nil { return true }
    let ruta = Bundle.main.bundlePath
    if ruta.hasPrefix("/Applications/") || ruta.hasPrefix(NSHomeDirectory() + "/Applications/") { return true }
    NSApp.activate(ignoringOtherApps: true)
    let a = NSAlert()
    a.messageText = "Mueve TalentoActivo a la carpeta Aplicaciones"
    a.informativeText =
      "Arrastra TalentoActivo a la carpeta Aplicaciones, ábrelo desde allí y listo. Así podrá iniciar solo cuando enciendas tu computadora."
    a.addButton(withTitle: "Entendido")
    a.runModal()
    NSApp.terminate(nil)
    return false
  }

  // MARK: Medición (un tic por minuto)

  private func programarMinuto() {
    // Se alinea con el cambio de minuto para que cada bloque de 5 minutos reciba 5 muestras.
    let ahora = Date().timeIntervalSince1970
    let siguiente = (ahora / 60).rounded(.down) * 60 + 60.5
    let t = Timer(fire: Date(timeIntervalSince1970: siguiente), interval: 60, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.tic() }
    }
    t.tolerance = 1
    RunLoop.main.add(t, forMode: .common)
    temporizador = t
  }

  private func tic() {
    if estado == .midiendo {
      medidor.registrar(activo: Medidor.segundosSinActividad() < 60, en: Date())
    }
    if estado == .midiendo || estado == .pausado { Task { await enviarPendientes() } }
    actualizarMenu()
  }

  private func enviarPendientes() async {
    guard nube.haySesion, !enviando, Date() >= noReintentarAntes else { return }
    let lote = medidor.primerosPendientes(100)
    guard !lote.isEmpty else { return }
    enviando = true
    defer { enviando = false }
    do {
      try await nube.enviar(lote)
      medidor.quitarEnviados(lote)
      conexionCaida = false
      ultimoEnvio = Date()
      if medidor.cola.count > 0 { noReintentarAntes = .distantPast }
    } catch ErrorNube.permiso {
      // La base de datos no aceptó el envío: falta aceptar la política. No se mide nada más.
      medidor.descartarTodo()
      estado = .sinPermiso
    } catch ErrorNube.credenciales {
      medidor.cerrarActual()
      estado = .sinSesion
      await iniciarSesionConDialogo(mensaje: "Tu sesión caducó. Vuelve a iniciar sesión.")
    } catch {
      conexionCaida = true
      noReintentarAntes = Date().addingTimeInterval(60)
    }
    actualizarMenu()
  }

  // MARK: Menú de la barra superior (siempre visible)

  private func construirMenu() {
    icono.button?.title = "TA"
    icono.button?.toolTip = "TalentoActivo"
    let menu = NSMenu()
    lineaEstado.isEnabled = false
    menu.addItem(lineaEstado)
    menu.addItem(.separator())

    botonPausa.target = self
    botonPausa.action = #selector(alternarPausa)
    menu.addItem(botonPausa)

    botonSesion.target = self
    botonSesion.action = #selector(accionSesion)
    menu.addItem(botonSesion)

    menu.addItem(.separator())
    menu.addItem(elemento("Abrir TalentoActivo en la web", #selector(abrirWeb)))
    menu.addItem(elemento("Qué mide este programa", #selector(queMide)))
    menu.addItem(.separator())
    menu.addItem(elemento("Desinstalar…", #selector(desinstalar)))
    menu.addItem(elemento("Salir", #selector(salir)))
    icono.menu = menu
  }

  private func elemento(_ titulo: String, _ accion: Selector) -> NSMenuItem {
    let e = NSMenuItem(title: titulo, action: accion, keyEquivalent: "")
    e.target = self
    return e
  }

  private func actualizarMenu() {
    let hora = DateFormatter()
    hora.timeStyle = .short
    hora.dateStyle = .none
    var texto: String
    switch estado {
    case .sinSesion: texto = "Sin iniciar sesión"
    case .midiendo: texto = "Midiendo actividad"
    case .pausado: texto = "En pausa: no se mide nada"
    case .sinPermiso: texto = "Falta aceptar la política en la web"
    }
    if estado == .midiendo || estado == .pausado {
      if conexionCaida {
        texto += " · sin conexión (\(medidor.cola.count) bloques por enviar)"
      } else if let u = ultimoEnvio {
        texto += " · último envío \(hora.string(from: u))"
      }
    }
    lineaEstado.title = texto
    icono.button?.title = estado == .midiendo ? "TA ●" : "TA ⏸"

    botonPausa.title = estado == .midiendo ? "Pausar" : "Reanudar"
    botonPausa.isEnabled = estado != .sinSesion
    botonSesion.title = nube.haySesion ? "Cerrar sesión (\(nube.sesion?.email ?? ""))" : "Iniciar sesión…"
  }

  // MARK: Acciones del menú

  @objc private func alternarPausa() {
    if estado == .midiendo {
      medidor.cerrarActual()
      estado = .pausado
    } else {
      estado = .midiendo
    }
    actualizarMenu()
    if estado == .midiendo { Task { await enviarPendientes() } }
  }

  @objc private func accionSesion() {
    if nube.haySesion {
      medidor.cerrarActual()
      nube.cerrarSesion()
      medidor.descartarTodo()
      estado = .sinSesion
      actualizarMenu()
    } else {
      Task { await iniciarSesionConDialogo(mensaje: nil) }
    }
  }

  @objc private func abrirWeb() {
    NSWorkspace.shared.open(URL(string: URL_SITIO)!)
  }

  @objc private func queMide() {
    NSApp.activate(ignoringOtherApps: true)
    let a = NSAlert()
    a.messageText = "Qué mide TalentoActivo"
    a.informativeText = """
      Cada minuto, revisa si usaste el teclado o el ratón: activo o inactivo. Cada 5 minutos \
      envía solo dos números: minutos activos y minutos inactivos.

      Nunca captura pantallas, lo que escribes, correos, páginas web, archivos, cámara ni micrófono.

      Puedes pausarlo o desinstalarlo cuando quieras desde este menú.
      """
    a.addButton(withTitle: "Cerrar")
    a.runModal()
  }

  @objc private func salir() {
    NSApp.terminate(nil)
  }

  @objc private func desinstalar() {
    NSApp.activate(ignoringOtherApps: true)
    let a = NSAlert()
    a.messageText = "¿Desinstalar TalentoActivo?"
    a.informativeText =
      "Se dejará de medir, se borrarán los datos guardados en esta computadora y el programa irá a la papelera. Lo que ya se envió se conserva según la política (30 días de detalle y 1 año de totales)."
    a.addButton(withTitle: "Desinstalar")
    a.addButton(withTitle: "Cancelar")
    a.alertStyle = .warning
    guard a.runModal() == .alertFirstButtonReturn else { return }

    temporizador?.invalidate()
    nube.cerrarSesion()
    medidor.descartarTodo()
    Almacen.borrar(Rutas.lanzador)
    try? FileManager.default.removeItem(at: Rutas.carpeta)
    NSWorkspace.shared.recycle([Bundle.main.bundleURL]) { _, _ in
      DispatchQueue.main.async { NSApp.terminate(nil) }
    }
  }

  // MARK: Inicio de sesión

  private func iniciarSesionConDialogo(mensaje: String?) async {
    guard !iniciandoSesion else { return }
    iniciandoSesion = true
    defer { iniciandoSesion = false }

    var aviso = mensaje
    while true {
      guard let (correo, clave) = pedirCredenciales(aviso: aviso) else {
        estado = .sinSesion
        actualizarMenu()
        return
      }
      do {
        try await nube.iniciarSesion(email: correo, password: clave)
        estado = .midiendo
        conexionCaida = false
        activarInicioAutomatico()
        actualizarMenu()
        return
      } catch ErrorNube.credenciales {
        aviso = "Correo o contraseña incorrectos."
      } catch ErrorNube.red {
        aviso = "No hay conexión a internet. Inténtalo de nuevo."
      } catch {
        aviso = "No pudimos iniciar sesión. Inténtalo en un momento."
      }
    }
  }

  private func pedirCredenciales(aviso: String?) -> (String, String)? {
    NSApp.activate(ignoringOtherApps: true)
    let alerta = NSAlert()
    alerta.messageText = "Inicia sesión en TalentoActivo"
    let extra = aviso.map { $0 + "\n\n" } ?? ""
    alerta.informativeText =
      extra
      + "Usa el mismo correo y contraseña de la página web. El programa guarda solo un permiso de sesión, nunca tu contraseña. Se abrirá solo al encender tu computadora; puedes pausarlo o desinstalarlo desde el ícono TA de la barra superior."
    alerta.addButton(withTitle: "Iniciar sesión")
    alerta.addButton(withTitle: "Cancelar")

    let correo = NSTextField(frame: NSRect(x: 0, y: 32, width: 280, height: 24))
    correo.placeholderString = "Correo"
    let clave = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
    clave.placeholderString = "Contraseña"
    let vista = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 56))
    vista.addSubview(correo)
    vista.addSubview(clave)
    alerta.accessoryView = vista
    alerta.window.initialFirstResponder = correo

    guard alerta.runModal() == .alertFirstButtonReturn else { return nil }
    let c = correo.stringValue.trimmingCharacters(in: .whitespaces)
    guard !c.isEmpty, !clave.stringValue.isEmpty else { return pedirCredenciales(aviso: "Escribe tu correo y tu contraseña.") }
    return (c, clave.stringValue)
  }

  // Arranca solo cuando la persona enciende la computadora (se quita al desinstalar).
  private func activarInicioAutomatico() {
    let plist: [String: Any] = [
      "Label": ETIQUETA_LANZADOR,
      "ProgramArguments": [Bundle.main.executablePath ?? ""],
      "RunAtLoad": true,
    ]
    guard let datos = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else { return }
    try? FileManager.default.createDirectory(
      at: Rutas.lanzador.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? datos.write(to: Rutas.lanzador, options: .atomic)
  }
}
