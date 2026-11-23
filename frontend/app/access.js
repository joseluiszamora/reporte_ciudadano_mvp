"use client";

import { useEffect, useState } from "react";
import { getApps, initializeApp } from "firebase/app";
import { getAuth, GoogleAuthProvider, onIdTokenChanged, signInWithPopup, signOut } from "firebase/auth";
import { LogIn, LogOut, UserRound, X } from "lucide-react";
import { api } from "./api-client.js";

const config = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || undefined,
};
const name = "reportes-web";

function getFirebaseAuth() {
  if (!config.apiKey || !config.projectId || !config.authDomain) return null;
  return getAuth(getApps().find((app) => app.name === name) ?? initializeApp(config, name));
}

export default function Access({ onChange }) {
  const [auth, setAuth] = useState(null);
  const [user, setUser] = useState(null);
  const [profile, setProfile] = useState(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    let service;
    try {
      service = getFirebaseAuth();
    } catch {
      setError("Revisa la configuración web de Firebase.");
    }
    if (!service) return;
    setAuth(service);
    let controller;
    const unsubscribe = onIdTokenChanged(service, async (account) => {
      controller?.abort();
      controller = new AbortController();
      const { signal } = controller;
      setUser(account);
      onChange(null);
      if (!account) {
        setProfile(null);
        setError("");
        return;
      }
      try {
        const { data } = await api("admin/session", { user: account, signal });
        if (signal.aborted) return;
        setProfile(data);
        setError("");
        onChange(data.publicName ? account : null);
        if (!data.publicName) setOpen(true);
      } catch (problem) {
        if (signal.aborted) return;
        setProfile(null);
        onChange(null);
        setError(problem.message);
        setOpen(true);
      }
    });
    return () => { controller?.abort(); unsubscribe(); };
  }, [onChange]);

  async function login() {
    setBusy(true);
    try {
      await signInWithPopup(auth, new GoogleAuthProvider());
    } catch (problem) {
      const text = problem.code === "auth/unauthorized-domain"
        ? "Autoriza 127.0.0.1 en Firebase Authentication o usa localhost."
        : "No se pudo iniciar sesión con Google. Comprueba la configuración de Firebase y vuelve a intentar.";
      setError(text);
    } finally {
      setBusy(false);
    }
  }

  async function saveProfile(event) {
    event.preventDefault();
    const publicName = new FormData(event.currentTarget).get("publicName");
    setBusy(true);
    try {
      const { data } = await api("admin/profile", { method: "PUT", user, body: { publicName } });
      setProfile(data);
      onChange(user);
      setError("");
      setOpen(false);
    } catch (problem) {
      setError(problem.message);
    } finally {
      setBusy(false);
    }
  }

  return <div className="access">
    <button type="button" className="button button-outline account-button" aria-expanded={open} onClick={() => setOpen(!open)}>
      <UserRound size={17} /> {profile?.publicName || "Acceso administrativo"}
    </button>
    {open && <section className="access-panel" aria-label="Acceso administrativo">
      <div className="access-heading">
        <strong>{profile?.publicName || "Acceso administrativo"}</strong>
        <button type="button" className="icon-button" aria-label="Cerrar acceso" onClick={() => setOpen(false)}><X size={18} /></button>
      </div>
      {error && <p role="alert" className="notice error">{error}</p>}
      {!auth && <p className="muted">Configura Firebase para habilitar la gestión de reportes.</p>}
      {auth && !user && <>
        <p className="muted">Usa una cuenta de Google con permisos de administración.</p>
        <button type="button" className="button button-primary" onClick={login} disabled={busy}><LogIn size={17} /> Entrar con Google</button>
      </>}
      {user && profile && !profile.publicName && <form className="form-stack" onSubmit={saveProfile}>
        <label>Nombre público<input name="publicName" minLength={2} maxLength={50} required /></label>
        <button className="button button-primary" disabled={busy}>Guardar nombre</button>
      </form>}
      {user && <button type="button" className="button button-outline" disabled={busy} onClick={() => signOut(auth).catch(() => setError("No se pudo cerrar la sesión."))}>
        <LogOut size={17} /> Cerrar sesión
      </button>}
    </section>}
  </div>;
}
