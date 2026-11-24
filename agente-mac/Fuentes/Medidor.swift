import CoreGraphics
import Foundation

// Mide actividad. Cada minuto pregunta una sola cosa al sistema: "¿cuántos segundos hace
// que se usó el teclado o el ratón?". Si fueron menos de 60, ese minuto cuenta como activo.
// No lee qué teclas se pulsan, ni pantallas, ni apps, ni páginas web.
// (No necesita permisos de Accesibilidad ni de Grabación de pantalla.)

@MainActor
final class Medidor {
  static let segundosPorBloque = 300.0
  static let maximoPendientes = 2016  // una semana de bloques; si no hay internet, se descartan los más viejos

  private(set) var actual: Bloque?
  private(set) var cola: [Bloque]
  private let persistir: Bool

  // persistir = false solo se usa en la autoprueba, para no tocar los archivos reales.
  init(cola: [Bloque]? = nil, persistir: Bool = true) {
    self.persistir = persistir
    self.cola = cola ?? Almacen.cargar([Bloque].self, Rutas.cola) ?? []
  }

  static func segundosSinActividad() -> Double {
    CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!)
  }

  // Anota el minuto que acaba de terminar en el bloque de 5 minutos que le corresponde.
  func registrar(activo: Bool, en ahora: Date) {
    let t = ahora.timeIntervalSince1970 - 1
    let inicio = Date(timeIntervalSince1970: (t / Self.segundosPorBloque).rounded(.down) * Self.segundosPorBloque)
    if let a = actual, a.inicio != inicio { cerrarActual() }
    if actual == nil { actual = Bloque(inicio: inicio, activos: 0, inactivos: 0) }
    if activo { actual?.activos += 1 } else { actual?.inactivos += 1 }
  }

  // Cierra el bloque en curso (al cambiar de bloque, pausar o salir) y lo deja listo para enviar.
  func cerrarActual() {
    if let a = actual, a.activos + a.inactivos > 0 { cola.append(a) }
    actual = nil
    if cola.count > Self.maximoPendientes { cola.removeFirst(cola.count - Self.maximoPendientes) }
    guardar()
  }

  func primerosPendientes(_ n: Int) -> [Bloque] { Array(cola.prefix(n)) }

  func quitarEnviados(_ enviados: [Bloque]) {
    cola.removeAll { enviados.contains($0) }
    guardar()
  }

  func descartarTodo() {
    actual = nil
    cola = []
    if persistir { Almacen.borrar(Rutas.cola) }
  }

  private func guardar() {
    if persistir { Almacen.guardar(cola, en: Rutas.cola) }
  }
}
