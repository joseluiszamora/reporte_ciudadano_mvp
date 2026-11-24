"use client";

import { useEffect, useState } from "react";
import { api, formatDate } from "./api-client.js";

const statuses = { PENDING: "Pendiente", APPROVED: "Aprobada", REJECTED: "Rechazada" };

function Evidence({ user, url }) {
  const [preview, setPreview] = useState("");
  const [error, setError] = useState("");
  const [opened, setOpened] = useState(false);
  useEffect(() => {
    if (!opened) return;
    const controller = new AbortController();
    let objectUrl;
    (async () => {
      const response = await fetch(url, {
        headers: { Authorization: "Bearer " + await user.getIdToken() }, signal: controller.signal,
      });
      if (!response.ok) throw new Error("No se pudo abrir la evidencia.");
      const blob = await response.blob();
      if (controller.signal.aborted) return;
      objectUrl = URL.createObjectURL(blob);
      setPreview(objectUrl);
    })().catch(() => {
      if (!controller.signal.aborted) setError("No se pudo abrir la evidencia.");
    });
    return () => {
      controller.abort();
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [opened, user, url]);
  if (!opened) return <button className="button button-outline" type="button" onClick={() => setOpened(true)}>Ver evidencia</button>;
  if (error) return <p role="alert" className="muted">{error}</p>;
  return preview ? <img className="evidence-photo" src={preview} alt="Evidencia de la propuesta" /> : <p role="status">Cargando evidencia…</p>;
}

export default function ProposalReview({ report, user, onReviewed }) {
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [selection, setSelection] = useState(null);
  const [saving, setSaving] = useState(false);
  useEffect(() => {
    const controller = new AbortController();
    api("reports/" + report.id + "/proposals", { user, signal: controller.signal })
      .then(({ data }) => setData(data))
      .catch((error) => { if (!controller.signal.aborted) setError(error.message); });
    return () => controller.abort();
  }, [report.id, report.revision, user]);

  async function decide(event) {
    event.preventDefault();
    if (saving) return;
    const reason = new FormData(event.currentTarget).get("reason");
    setSaving(true);
    setError("");
    try {
      await api("admin/proposals/" + selection.id, { user, method: "PATCH", body: { reason, action: selection.action } });
      setSelection(null);
      onReviewed();
    } catch (problem) {
      setError(problem.message);
    } finally {
      setSaving(false);
    }
  }

  return <section className="manage" aria-labelledby="proposal-heading">
    <h3 id="proposal-heading">Propuestas de solución</h3>
    {error && <p role="alert" className="notice error">{error}</p>}
    {!data && !error && <p role="status">Cargando propuestas…</p>}
    {data?.length === 0 && <p className="muted">Todavía no hay propuestas.</p>}
    {data?.map((proposal) => <article className="proposal-card" key={proposal.id}>
      <div className="detail-meta"><strong>{statuses[proposal.status]}</strong><span>{formatDate(proposal.createdAt)}</span></div>
      <p>{proposal.note}</p>
      {proposal.evidenceUrl && <Evidence user={user} url={proposal.evidenceUrl} />}
      {proposal.reviewNote && <p className="muted">{proposal.reviewNote}</p>}
      {proposal.status === "PENDING" && report.status !== "RESOLVED" &&
        (selection?.id === proposal.id ? <form className="form-stack" onSubmit={decide}>
          <label>Motivo de la decisión<textarea name="reason" rows={3} minLength={10} maxLength={1000} required /></label>
          <div className="manage-buttons">
            <button className="button button-primary" disabled={saving}>{selection.action === "approve" ? "Confirmar aprobación" : "Confirmar rechazo"}</button>
            <button type="button" className="button button-outline" disabled={saving} onClick={() => setSelection(null)}>Cancelar</button>
          </div>
        </form> : <div className="manage-buttons">
          <button type="button" className="button button-outline" disabled={saving} onClick={() => setSelection({ id: proposal.id, action: "approve" })}>Aprobar</button>
          <button type="button" className="button button-outline" disabled={saving} onClick={() => setSelection({ id: proposal.id, action: "reject" })}>Rechazar</button>
        </div>)}
    </article>)}
  </section>;
}
