// Selección común de tareas, con nombres de quien pide y de quien la hace.
export const SELECCION_TAREA =
  'id, titulo, descripcion, tipo, estado, horas_estimadas, creada_en, ' +
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
