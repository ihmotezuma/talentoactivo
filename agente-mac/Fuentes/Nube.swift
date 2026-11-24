import Foundation

// Comunicación con Supabase. El programa inicia sesión como la propia persona, así que las
// reglas de privacidad de la base de datos (RLS) se aplican igual que en la página web:
// solo puede enviar actividad propia y solo si aceptó la política vigente.

enum ErrorNube: Error {
  case sinSesion
  case credenciales  // correo o contraseña mal, o la sesión caducó
  case permiso  // la base de datos rechazó el envío (falta aceptar la política)
  case red  // sin internet
  case servidor(Int)
}

struct Sesion: Codable {
  var refreshToken: String
  var email: String
  var userId: String
}

struct Bloque: Codable, Equatable {
  var inicio: Date
  var activos: Int
  var inactivos: Int
}

// Esto es TODO lo que el programa envía: quién (la propia persona), cuándo, y dos números.
private struct FilaActividad: Encodable {
  let perfil_id: String
  let inicio: String
  let minutos_activos: Int
  let minutos_inactivos: Int
  let origen = "agente"
}

@MainActor
final class Nube {
  private(set) var sesion: Sesion?
  private var accessToken: String?
  private var expira = Date.distantPast

  init() {
    sesion = Almacen.cargar(Sesion.self, Rutas.sesion)
  }

  var haySesion: Bool { sesion != nil }

  private struct RespuestaToken: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
    let user: Usuario
    struct Usuario: Decodable { let id: String }
  }

  private func peticion(_ ruta: String, metodo: String, cuerpo: Data, extra: [String: String] = [:]) -> URLRequest {
    var req = URLRequest(url: URL(string: SUPABASE_URL + ruta)!)
    req.httpMethod = metodo
    req.timeoutInterval = 30
    req.setValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    for (k, v) in extra { req.setValue(v, forHTTPHeaderField: k) }
    req.httpBody = cuerpo
    return req
  }

  private func ejecutar(_ req: URLRequest) async throws -> (Data, Int) {
    do {
      let (datos, resp) = try await URLSession.shared.data(for: req)
      return (datos, (resp as? HTTPURLResponse)?.statusCode ?? 0)
    } catch {
      throw ErrorNube.red
    }
  }

  private func pedirToken(grant: String, cuerpo: [String: String]) async throws -> RespuestaToken {
    let datos = try JSONSerialization.data(withJSONObject: cuerpo)
    let (resp, codigo) = try await ejecutar(peticion("/auth/v1/token?grant_type=\(grant)", metodo: "POST", cuerpo: datos))
    if codigo == 400 || codigo == 401 || codigo == 403 { throw ErrorNube.credenciales }
    guard codigo == 200, let r = try? JSONDecoder().decode(RespuestaToken.self, from: resp) else {
      throw ErrorNube.servidor(codigo)
    }
    return r
  }

  private func recibir(_ r: RespuestaToken, email: String) {
    accessToken = r.access_token
    expira = Date().addingTimeInterval(TimeInterval(r.expires_in))
    // Se guarda el permiso de sesión (refresh token), NUNCA la contraseña.
    let nueva = Sesion(refreshToken: r.refresh_token, email: email, userId: r.user.id)
    sesion = nueva
    Almacen.guardar(nueva, en: Rutas.sesion)
  }

  func iniciarSesion(email: String, password: String) async throws {
    let r = try await pedirToken(grant: "password", cuerpo: ["email": email, "password": password])
    recibir(r, email: email)
  }

  func cerrarSesion() {
    sesion = nil
    accessToken = nil
    expira = .distantPast
    Almacen.borrar(Rutas.sesion)
  }

  private func asegurarToken() async throws {
    if accessToken != nil, expira > Date().addingTimeInterval(60) { return }
    guard let s = sesion else { throw ErrorNube.sinSesion }
    do {
      let r = try await pedirToken(grant: "refresh_token", cuerpo: ["refresh_token": s.refreshToken])
      recibir(r, email: s.email)
    } catch ErrorNube.credenciales {
      cerrarSesion()
      throw ErrorNube.credenciales
    }
  }

  func enviar(_ bloques: [Bloque]) async throws {
    guard let s = sesion else { throw ErrorNube.sinSesion }
    let formato = ISO8601DateFormatter()
    formato.formatOptions = [.withInternetDateTime]
    let filas = bloques.map {
      FilaActividad(
        perfil_id: s.userId, inicio: formato.string(from: $0.inicio),
        minutos_activos: $0.activos, minutos_inactivos: $0.inactivos)
    }
    let cuerpo = try JSONEncoder().encode(filas)

    for intento in 0..<2 {
      try await asegurarToken()
      let extra = [
        "Authorization": "Bearer \(accessToken ?? "")",
        // Si un bloque ya estaba enviado (por un reintento), se ignora en vez de fallar.
        "Prefer": "resolution=ignore-duplicates,return=minimal",
      ]
      let (_, codigo) = try await ejecutar(
        peticion("/rest/v1/actividad_bloques?on_conflict=perfil_id,inicio", metodo: "POST", cuerpo: cuerpo, extra: extra))
      switch codigo {
      case 200..<300: return
      case 401 where intento == 0:
        accessToken = nil
        expira = .distantPast
      case 401: throw ErrorNube.credenciales
      case 403: throw ErrorNube.permiso
      default: throw ErrorNube.servidor(codigo)
      }
    }
  }
}
