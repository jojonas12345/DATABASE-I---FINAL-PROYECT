// Definicion del menu por modulo y los roles que pueden verlo.
// El Layout filtra estos items segun el rol del usuario logueado.
// Roles del sistema: Administrador, Recepcion, Tecnico, Bodega, Caja.

export const MENU = [
  { label: "Dashboard",         path: "/",           roles: ["Administrador", "Recepcion", "Tecnico", "Bodega", "Caja"] },
  { label: "Ordenes",           path: "/ordenes",    roles: ["Administrador", "Recepcion", "Tecnico", "Caja"] },
  { label: "Clientes y Equipos", path: "/clientes",  roles: ["Administrador", "Recepcion"] },
  { label: "Inventario / Bodega", path: "/inventario", roles: ["Administrador", "Bodega"] },
  { label: "Caja",              path: "/caja",       roles: ["Administrador", "Caja"] },
  { label: "Reportes",          path: "/reportes",   roles: ["Administrador", "Recepcion", "Tecnico", "Bodega", "Caja"] },
  { label: "Administracion",    path: "/admin",      roles: ["Administrador"] },
];

// Devuelve solo los items que el rol puede ver.
export function menuParaRol(rol) {
  return MENU.filter((m) => m.roles.includes(rol));
}

// Util: saber si un rol puede entrar a una ruta.
export function rolPuedeVer(rol, path) {
  const item = MENU.find((m) => m.path === path);
  return item ? item.roles.includes(rol) : true;
}
