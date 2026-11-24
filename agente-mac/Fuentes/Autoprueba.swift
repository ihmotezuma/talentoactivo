import Foundation

@MainActor
enum Autoprueba {
  static func ejecutar() {
    var fallos = 0
    func comprobar(_ condicion: Bool, _ texto: String) {
      print(condicion ? "OK     " : "FALLÓ  ", texto)
      if !condicion { fallos += 1 }
    }

    // 12:00:00 UTC de un día cualquiera, alineado a 5 minutos.
    let base = Date(timeIntervalSince1970: 1_800_000_000 - 1_800_000_000.truncatingRemainder(dividingBy: 300))
    func tic(_ minuto: Int) -> Date { base.addingTimeInterval(Double(minuto) * 60 + 0.5) }

    // 10 minutos: los primeros 5 siempre activos, los siguientes 5 con 2 activos.
    let m = Medidor(cola: [], persistir: false)
    for i in 1...10 {
      m.registrar(activo: i <= 5 || i == 6 || i == 7, en: tic(i))
    }
    m.cerrarActual()
    comprobar(m.cola.count == 2, "10 minutos forman 2 bloques (hay \(m.cola.count))")
    if m.cola.count == 2 {
      comprobar(m.cola[0].activos + m.cola[0].inactivos == 5, "el primer bloque suma 5 minutos")
      comprobar(m.cola[0].activos == 5 && m.cola[0].inactivos == 0, "primer bloque: 5 activos y 0 inactivos")
      comprobar(m.cola[1].activos == 2 && m.cola[1].inactivos == 3, "segundo bloque: 2 activos y 3 inactivos")
      comprobar(
        m.cola[0].inicio.timeIntervalSince1970.truncatingRemainder(dividingBy: 300) == 0,
        "el inicio del bloque cae en múltiplo de 5 minutos")
      comprobar(m.cola[1].inicio.timeIntervalSince(m.cola[0].inicio) == 300, "los bloques están separados 5 minutos")
    }

    // Bloque parcial (la computadora durmió): 2 muestras siguen siendo válidas (entre 1 y 10).
    let p = Medidor(cola: [], persistir: false)
    p.registrar(activo: true, en: tic(1))
    p.registrar(activo: false, en: tic(2))
    p.cerrarActual()
    comprobar(p.cola.count == 1 && p.cola[0].activos + p.cola[0].inactivos == 2, "bloque parcial de 2 minutos se conserva")

    // Quitar lo enviado.
    let q = Medidor(cola: [], persistir: false)
    for i in 1...15 { q.registrar(activo: true, en: tic(i)) }
    q.cerrarActual()
    let lote = q.primerosPendientes(2)
    q.quitarEnviados(lote)
    comprobar(q.cola.count == 1, "tras enviar 2 de 3 bloques queda 1")
    q.descartarTodo()

    // Lectura real del sistema (solo comprueba que devuelve un número razonable).
    let s = Medidor.segundosSinActividad()
    comprobar(s >= 0 && s < 10_000_000, "lectura de inactividad del sistema: \(Int(s)) s")

    print(fallos == 0 ? "\nTodo bien." : "\nHay \(fallos) fallo(s).")
    if fallos > 0 { exit(1) }
  }
}
