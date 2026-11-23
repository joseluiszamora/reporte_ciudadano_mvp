import "./styles.css";

export const metadata = {
  title: "Reportes Ciudadanos · El Alto",
  description: "Panel de consulta y gestión de reportes ciudadanos de El Alto.",
};

export default function RootLayout({ children }) {
  return <html lang="es-BO"><body>{children}</body></html>;
}
