"use client";

import { useEffect, useRef, useState } from "react";
import { CalendarDays, Clock3, Image, MapPin, Pencil, Trash2, X } from "lucide-react";
import Status from "./status.js";
import { api, formatDate, statusText } from "./api-client.js";

const transitions = {
  REPORTED: { label: "Iniciar seguimiento", status: "IN_FOLLOW_UP" },
  IN_FOLLOW_UP: { label: "Devolver a reportado", status: "REPORTED" },
  RESOLVED: { label: "Reabrir reporte", status: "IN_FOLLOW_UP" },
};

export default function ReportDetail({ id, admin, categories, onClose, onChange }) {
  const dialog = useRef(null);
  const [report, setReport] = useState(null);
  const [mode, setMode] = useState("");
  const [loadError, setLoadError] = useState("");
  const [saveError, setSaveError] = useState("");
  const [success, setSuccess] = useState("");
  const [version, setVersion] = useState(0);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const panel = dialog.current;
    panel.showModal();
    return () => panel.close();
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    const { signal } = controller;
    api("reports/" + id, { signal }).then(({ data }) => {
      if (!signal.aborted) { setReport(data); setLoadError(""); }
    }).catch((error) => {
      if (!signal.aborted) { setReport(null); setLoadError(error.message); }
    });
    return () => controller.abort();
  }, [id, version]);

  function changeMode(next) {
    setMode(next);
    setSaveError("");
    setSuccess("");
  }

  async function save(event) {
    event.preventDefault();
    if (saving || !admin) return;
    const form = new FormData(event.currentTarget);
    const body = { action: mode, revision: report.revision, reason: form.get("reason") };
    if (mode === "status") body.status = transitions[report.status].status;
    if (mode === "edit") Object.assign(body, {
      title: form.get("title"),
      description: form.get("description"),
      categoryId: form.get("categoryId"),
      addressLabel: form.get("addressLabel").trim() || null,
      latitude: Number(form.get("latitude")),
      longitude: Number(form.get("longitude")),
    });

    setSaving(true);
    setSaveError("");
    try {
      await api("admin/reports/" + id, { method: "PATCH", body, user: admin });
      onChange(mode === "delete");
      if (mode !== "delete") {
        setMode("");
        setSuccess("Cambios guardados.");
        setReport(null);
        setVersion((value) => value + 1);
      }
    } catch (error) {
      setSaveError(error.message);
    } finally {
      setSaving(false);
    }
  }

  const action = report && transitions[report.status];
  const mapHref = report && `https://www.openstreetmap.org/?mlat=${report.latitude}&mlon=${report.longitude}#map=17/${report.latitude}/${report.longitude}`;

  return <dialog ref={dialog} className="detail" aria-labelledby="detail-title" onCancel={(event) => {
    event.preventDefault();
    if (!saving) onClose();
  }}>
    <header className="detail-header">
      <div><span className="detail-category">{report?.category.name || "Reporte"}</span>
        <h2 id="detail-title">{report?.title || "Detalle del reporte"}</h2></div>
      <button type="button" className="icon-button" disabled={saving} onClick={onClose} aria-label="Cerrar detalle"><X size={21} /></button>
    </header>
    <div className="detail-body">
      {loadError ? <p className="notice error" role="alert">{loadError}</p> : !report ? <p role="status">Cargando detalle…</p> : <>
        {success && <p className="notice success" role="status">{success}</p>}
        <div className="detail-meta"><Status status={report.status} /><span><CalendarDays size={16} /> {formatDate(report.createdAt)}</span><span>{report.publicName}</span>
          {report.resolvedAt && <span>Solucionado el {formatDate(report.resolvedAt)}</span>}</div>
        <p className="report-description">{report.description}</p>
        <div className="detail-location">
          <MapPin size={20} /><div><strong>{report.addressLabel || "Ubicación del reporte"}</strong>
            <span>{report.latitude.toFixed(5)}, {report.longitude.toFixed(5)}</span></div>
          <a href={mapHref} target="_blank" rel="noreferrer" className="button button-outline">Ver mapa</a>
        </div>
        {!!report.images.length && <p className="image-meta"><Image size={17} /> {report.images.length} {report.images.length === 1 ? "imagen registrada" : "imágenes registradas"}</p>}
        <section className="history" aria-labelledby="history-title">
          <h3 id="history-title"><Clock3 size={17} /> Historial de estados</h3>
          {report.history.length ? <ol>{report.history.map((event, index) => <li key={index}>
            <strong>{event.fromStatus ? statusText[event.toStatus] : "Reporte creado"}</strong>
            <span>{formatDate(event.createdAt)}</span>
            {event.note && <p>{event.note}</p>}
          </li>)}</ol> : <p className="muted">Aún no hay cambios registrados.</p>}
        </section>
        {admin && <section className="manage" aria-labelledby="manage-title">
          <h3 id="manage-title">Gestión del reporte</h3>
          {!mode ? <div className="manage-buttons">
            <button type="button" className="button button-outline" onClick={() => changeMode("edit")}><Pencil size={16} /> Editar reporte</button>
            <button type="button" className="button button-outline" onClick={() => changeMode("status")}>{action.label}</button>
            <button type="button" className="button button-outline danger-text" onClick={() => changeMode("delete")}><Trash2 size={16} /> Retirar reporte</button>
          </div> : <form className="form-stack" onSubmit={save} key={mode}>
            <strong>{mode === "status" ? action.label : mode === "delete" ? "Retirar del listado público" : "Editar reporte"}</strong>
            {mode === "edit" && <>
              <label>Título<input name="title" defaultValue={report.title} minLength={10} maxLength={100} required /></label>
              <label>Descripción<textarea name="description" defaultValue={report.description} minLength={20} maxLength={2000} rows={4} required /></label>
              <label>Categoría<select name="categoryId" defaultValue={report.category.id} required>
                {!categories.some((category) => category.id === report.category.id) && <option value={report.category.id}>{report.category.name}</option>}
                {categories.map((category) => <option key={category.id} value={category.id}>{category.name}</option>)}
              </select></label>
              <label>Referencia de ubicación<input name="addressLabel" defaultValue={report.addressLabel ?? ""} maxLength={250} /></label>
              <div className="coordinate-fields">
                <label>Latitud<input name="latitude" type="number" step="any" min={-90} max={90} defaultValue={report.latitude} required /></label>
                <label>Longitud<input name="longitude" type="number" step="any" min={-180} max={180} defaultValue={report.longitude} required /></label>
              </div>
            </>}
            <label>Motivo <small>{mode === "status" ? "El motivo aparecerá en el historial público." : "10 a 1.000 caracteres"}</small>
              <textarea name="reason" minLength={10} maxLength={1000} rows={3} required /></label>
            {saveError && <p className="notice error" role="alert">{saveError}</p>}
            <div className="manage-buttons">
              <button className={`button ${mode === "delete" ? "button-danger" : "button-primary"}`} disabled={saving}>
                {saving ? "Guardando…" : mode === "delete" ? "Confirmar retiro" : "Guardar cambio"}
              </button>
              <button type="button" className="button button-outline" disabled={saving} onClick={() => changeMode("")}>Cancelar</button>
              {saveError && <button type="button" className="button button-outline" onClick={() => {
                changeMode(""); setReport(null); setVersion((value) => value + 1);
              }}>Actualizar detalle</button>}
            </div>
          </form>}
        </section>}
      </>}
    </div>
  </dialog>;
}
