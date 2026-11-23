const messages = {
  API_UNAVAILABLE: "La API no está disponible. Verifica que el backend esté en ejecución.",
  AUTH_REQUIRED: "Vuelve a iniciar sesión con Google.",
  AUTH_UNAVAILABLE: "La autenticación del backend todavía no está configurada.",
  ADMIN_REQUIRED: "Tu cuenta no tiene permisos de administración.",
  PROFILE_REQUIRED: "Completa tu nombre público antes de gestionar reportes.",
  INVALID_PROFILE: "Escribe un nombre de entre 2 y 50 caracteres.",
  REPORT_CONFLICT: "El reporte cambió mientras lo revisabas. Actualiza el detalle e inténtalo de nuevo.",
  INVALID_CATEGORY: "Selecciona una categoría activa.",
  INVALID_TRANSITION: "Ese cambio de estado no está disponible.",
  INVALID_REPORT_CHANGE: "Revisa el contenido y escribe un motivo de 10 a 1.000 caracteres.",
  NOT_FOUND: "El reporte ya no está disponible.",
};

export async function api(path, { method = "GET", body, user, signal } = {}) {
  const headers = {};
  if (user) headers.Authorization = "Bearer " + await user.getIdToken();
  if (body) headers["Content-Type"] = "application/json";
  const response = await fetch("/api/" + path, {
    method, headers, body: body ? JSON.stringify(body) : undefined, signal, cache: "no-store",
  });
  const result = await response.json();
  if (!response.ok) throw new Error(messages[result.error] ?? "No se pudo completar la solicitud.");
  return result;
}

export const statusText = {
  REPORTED: "Reportado",
  IN_FOLLOW_UP: "En seguimiento",
  RESOLVED: "Solucionado",
};

const dateFormat = new Intl.DateTimeFormat("es-BO", {
  dateStyle: "medium", timeZone: "America/La_Paz",
});

export function formatDate(value) {
  return dateFormat.format(new Date(value));
}
