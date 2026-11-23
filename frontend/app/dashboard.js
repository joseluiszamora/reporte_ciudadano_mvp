"use client";

import { useEffect, useState } from "react";
import {
  Archive, ArrowDownUp, CheckCircle2, ChevronDown, CircleAlert, ClipboardList,
  Clock3, Database, FileSearch, FlaskConical, LayoutGrid, ListFilter, MapPin,
  RefreshCw, Search, ShieldCheck,
} from "lucide-react";
import Access from "./access.js";
import ReportDetail from "./report-detail.js";
import Status from "./status.js";
import { api, formatDate, statusText } from "./api-client.js";

const pageSize = 10;
const cards = [
  { key: "total", filter: "", label: "Total de reportes", icon: ClipboardList, color: "violet" },
  { key: "REPORTED", filter: "REPORTED", label: "Reportados", icon: CircleAlert, color: "blue" },
  { key: "IN_FOLLOW_UP", filter: "IN_FOLLOW_UP", label: "En seguimiento", icon: Clock3, color: "amber" },
  { key: "RESOLVED", filter: "RESOLVED", label: "Solucionados", icon: CheckCircle2, color: "green" },
];

export default function Dashboard() {
  const [categories, setCategories] = useState([]);
  const [summary, setSummary] = useState(null);
  const [catalogError, setCatalogError] = useState("");
  const [page, setPage] = useState(null);
  const [loadError, setLoadError] = useState("");
  const [draft, setDraft] = useState("");
  const [query, setQuery] = useState("");
  const [categoryId, setCategory] = useState("");
  const [status, setStatus] = useState("");
  const [order, setOrder] = useState("desc");
  const [demo, setDemo] = useState(false);
  const [offset, setOffset] = useState(0);
  const [refresh, setRefresh] = useState(0);
  const [detail, setDetail] = useState(null);
  const [admin, setAdmin] = useState(null);
  const [feedback, setFeedback] = useState("");

  useEffect(() => {
    const controller = new AbortController();
    const { signal } = controller;
    setCatalogError("");
    api("categories", { signal }).then(({ data }) => setCategories(data)).catch((error) => {
      if (!signal.aborted) setCatalogError(error.message);
    });
    return () => controller.abort();
  }, [refresh]);

  useEffect(() => {
    const controller = new AbortController();
    const { signal } = controller;
    setSummary(null);
    api("reports/summary?demo=" + demo, { signal }).then(({ data }) => setSummary(data)).catch(() => {});
    return () => controller.abort();
  }, [demo, refresh]);

  useEffect(() => {
    const controller = new AbortController();
    const { signal } = controller;
    const params = new URLSearchParams({ q: query, order, demo, offset, limit: pageSize });
    if (categoryId) params.set("categoryId", categoryId);
    if (status) params.set("status", status);
    setPage(null);
    setLoadError("");
    api("reports?" + params, { signal }).then((result) => {
      if (!signal.aborted) setPage(result);
    }).catch((error) => {
      if (!signal.aborted) setLoadError(error.message);
    });
    return () => controller.abort();
  }, [query, categoryId, status, order, demo, offset, refresh]);

  function filter(setValue, value) {
    setOffset(0);
    setValue(value);
  }

  function onSearch(event) {
    event.preventDefault();
    filter(setQuery, draft.trim());
  }

  function clearFilters() {
    setDraft("");
    setQuery("");
    setCategory("");
    setStatus("");
    setOffset(0);
  }

  const hasFilters = Boolean(query || categoryId || status);
  const end = offset + (page?.data.length ?? 0);
  const retry = () => setRefresh((value) => value + 1);

  return <div className="shell">
    <aside className="sidebar">
      <a className="brand" href="#resumen">
        <span className="brand-mark"><MapPin size={23} strokeWidth={2.5} /></span>
        <span><strong>Reportes Ciudadanos</strong><small>Municipio de El Alto</small></span>
      </a>
      <nav className="navigation" aria-label="Navegación principal">
        <a href="#resumen"><LayoutGrid size={18} /> Resumen</a>
        <a href="#reportes" className="nav-current"><ClipboardList size={18} /> Reportes</a>
      </nav>
      <div className="sidebar-footer"><ShieldCheck size={19} /><span>Panel ciudadano<small>El Alto, Bolivia</small></span></div>
    </aside>

    <main className="workspace">
      <header className="topbar">
        <span className="breadcrumb"><LayoutGrid size={16} /> Panel <span>/</span> <strong>Reportes</strong></span>
        <Access onChange={setAdmin} />
      </header>
      <div className="content">
        <section id="resumen" className="overview" aria-labelledby="page-title">
          <div className="overview-header">
            <div><h1 id="page-title">Reportes ciudadanos</h1>
              <p>Consulta y da seguimiento a los reportes de El Alto.</p></div>
            <div className="view-toggle" aria-label="Origen de reportes">
              <button type="button" onClick={() => filter(setDemo, false)} aria-pressed={!demo}><Database size={16} /> Reales</button>
              <button type="button" onClick={() => filter(setDemo, true)} aria-pressed={demo}><FlaskConical size={16} /> Demostración</button>
            </div>
          </div>
          <div className="metrics">
            {cards.map(({ key, filter: value, label, icon: Icon, color }) => <button
              type="button" className="metric" key={key} aria-pressed={status === value}
              onClick={() => filter(setStatus, value)}>
              <span className={`metric-icon ${color}`}><Icon size={21} strokeWidth={2} /></span>
              <span className="metric-label">{label}</span>
              <strong>{summary?.[key]?.toLocaleString("es-BO") ?? "—"}</strong>
            </button>)}
          </div>
        </section>

        <section id="reportes" className="report-panel" aria-labelledby="list-title">
          <div className="panel-heading">
            <div><h2 id="list-title">Listado de reportes</h2><p>{demo ? "Registros de demostración" : "Registros en la base de datos"}</p></div>
            <button type="button" className="icon-button refresh" title="Actualizar reportes" aria-label="Actualizar reportes" onClick={retry}>
              <RefreshCw size={18} />
            </button>
          </div>
          <div className="filterbar">
            <form className="searchbar" role="search" onSubmit={onSearch}>
              <label className="search-control">
                <Search size={19} /><input type="search" aria-label="Buscar reportes" placeholder="Buscar por título o descripción"
                  maxLength={200} value={draft} onChange={(event) => {
                    const value = event.target.value;
                    setDraft(value);
                    if (!value) filter(setQuery, "");
                  }} />
              </label>
              <button className="button button-primary">Buscar</button>
            </form>
            <div className="filter-options">
              <label className="select-control">
                <ListFilter size={17} /><select aria-label="Categoría" value={categoryId} onChange={(event) => filter(setCategory, event.target.value)}>
                  <option value="">Todas las categorías</option>
                  {categories.map((category) => <option key={category.id} value={category.id}>{category.name}</option>)}
                </select><ChevronDown size={15} />
              </label>
              <label className="select-control">
                <select aria-label="Estado" value={status} onChange={(event) => filter(setStatus, event.target.value)}>
                  <option value="">Todos los estados</option>
                  {Object.entries(statusText).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                </select><ChevronDown size={15} />
              </label>
              <button type="button" className="icon-button sort" aria-label={order === "desc" ? "Ordenar del más antiguo al más reciente" : "Ordenar del más reciente al más antiguo"}
                title={order === "desc" ? "Más recientes primero" : "Más antiguos primero"}
                onClick={() => filter(setOrder, order === "desc" ? "asc" : "desc")}><ArrowDownUp size={17} /></button>
            </div>
          </div>
          {(feedback || catalogError) && <p role={catalogError ? "alert" : "status"} className={`notice table-notice ${catalogError ? "error" : "success"}`}>{catalogError || feedback}</p>}
          <div className="table-wrap">
            <table>
              <thead><tr><th scope="col">Reporte</th><th scope="col">Categoría</th><th scope="col">Estado</th><th scope="col">Fecha</th><th scope="col"><span className="sr-only">Detalle</span></th></tr></thead>
              <tbody>
                {page?.data.map((report) => <tr key={report.id}>
                  <td><strong>{report.title}</strong><small>{report.publicName}</small></td>
                  <td>{report.category.name}</td><td><Status status={report.status} /></td>
                  <td>{formatDate(report.createdAt)}</td>
                  <td><button type="button" className="button button-row" aria-label={`Ver detalle de ${report.title}`} onClick={() => setDetail(report.id)}>Ver detalle</button></td>
                </tr>)}
                {!page?.data.length && <tr><td colSpan={5}>
                  <div className="empty" role={loadError ? "alert" : "status"}>
                    <span className="empty-icon">{loadError ? <CircleAlert size={27} /> : hasFilters ? <FileSearch size={27} /> : <Archive size={27} />}</span>
                    <strong>{loadError ? "No se pudieron cargar los reportes" : !page ? "Cargando reportes…" : hasFilters ? "No hay coincidencias" : "Todavía no hay reportes"}</strong>
                    {(loadError || page) && <p>{loadError || (hasFilters ? "Prueba con otra búsqueda o cambia los filtros." : "Los reportes guardados en la base de datos aparecerán aquí.")}</p>}
                    {loadError && <button type="button" className="button button-outline" onClick={retry}>Reintentar</button>}
                    {!loadError && page && hasFilters && <button type="button" className="button button-outline" onClick={clearFilters}>Limpiar filtros</button>}
                  </div>
                </td></tr>}
              </tbody>
            </table>
          </div>
          <footer className="table-footer">
            <span>{end > offset ? `Mostrando ${offset + 1}–${end}` : "0 reportes en esta página"}</span>
            <div>
              <button type="button" className="button button-outline" disabled={!offset || !page} onClick={() => setOffset(Math.max(0, offset - pageSize))}>Anterior</button>
              <button type="button" className="button button-outline" disabled={page?.nextOffset == null} onClick={() => setOffset(page.nextOffset)}>Siguiente</button>
            </div>
          </footer>
        </section>
      </div>
    </main>
    {detail && <ReportDetail id={detail} admin={admin} categories={categories}
      onClose={() => setDetail(null)} onChange={(deleted) => {
        if (deleted) { setDetail(null); setOffset(0); }
        setFeedback(deleted ? "El reporte se retiró del listado público." : "Cambios guardados.");
        retry();
      }} />}
  </div>;
}
