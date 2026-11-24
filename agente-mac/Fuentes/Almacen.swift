import Foundation

// Dónde guarda el programa sus archivos (solo en la computadora de la persona).
enum Rutas {
  static let carpeta: URL = {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let url = base.appendingPathComponent("TalentoActivo")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }()
  static var sesion: URL { carpeta.appendingPathComponent("sesion.json") }
  static var cola: URL { carpeta.appendingPathComponent("pendientes.json") }
  static var lanzador: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/LaunchAgents/\(ETIQUETA_LANZADOR).plist")
  }
}

let ETIQUETA_LANZADOR = "ve.ucab.talentoactivo.agente"

enum Almacen {
  static func cargar<T: Decodable>(_ tipo: T.Type, _ url: URL) -> T? {
    guard let datos = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder.conFechas.decode(tipo, from: datos)
  }

  // Los archivos solo los puede leer la propia persona (permisos 600).
  static func guardar<T: Encodable>(_ valor: T, en url: URL) {
    guard let datos = try? JSONEncoder.conFechas.encode(valor) else { return }
    try? datos.write(to: url, options: .atomic)
    try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
  }

  static func borrar(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
  }
}

extension JSONEncoder {
  static var conFechas: JSONEncoder {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    return e
  }
}

extension JSONDecoder {
  static var conFechas: JSONDecoder {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }
}
