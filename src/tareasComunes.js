// Selección común de tareas, con nombres de quien pide y de quien la hace.
export const SELECCION_TAREA =
  'id, titulo, descripcion, tipo, estado, horas_estimadas, creada_en, asignado_a_id:asignada_a, ' +
  'area:areas(nombre), ' +
  'creador:perfiles!tareas_creada_por_fkey(nombre), ' +
  'asignado:perfiles!tareas_asignada_a_fkey(nombre), ' +
  'tarea_habilidades(habilidades(nombre))'

export const ETIQUETA_ESTADO = {
  publicada: 'Publicada',
  asignada: 'Esperando respuesta',
  en_curso: 'En curso',
  en_revision: 'En revisión',
  aprobada: 'Aprobada',
  cancelada: 'Cancelada',
}

// Escoge singular o plural según la cantidad: plural(1, 'tarea', 'tareas') → 'tarea'
export function plural(n, singular, plurales) {
  return n === 1 ? singular : plurales
}
