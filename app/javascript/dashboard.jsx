import React, { useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";

const money = new Intl.NumberFormat("es-CL", { maximumFractionDigits: 0 });
const timestamp = (value) => value ? new Intl.DateTimeFormat("es-CL", { dateStyle: "medium", timeStyle: "short" }).format(new Date(value)) : "—";
const title = (value) => ({ pickup: "Retiro en local", delivery: "A domicilio", pending: "Pendiente", sent: "Enviado", error: "Error de despacho" }[value] || "Desconocido");
const modalBackdropStyle = { position: "fixed", inset: 0, zIndex: 1000, display: "grid", placeItems: "center", padding: "1rem", background: "rgba(0, 0, 0, 0.72)" };
const modalPanelStyle = { position: "relative", width: "min(100%, 36rem)", maxHeight: "min(85vh, 48rem)", overflowY: "auto", padding: "1.5rem", borderRadius: "1rem", background: "#232227", color: "#fff", boxShadow: "0 1rem 3rem rgba(0, 0, 0, 0.4)" };

export function mapOrders(orders, restaurants) {
  const restaurantById = new Map(restaurants.map((restaurant) => [String(restaurant.id), restaurant.name]));
  return orders.map((order) => ({ ...order, restaurantName: restaurantById.get(String(order.restaurant_id)) || `Restaurante #${order.restaurant_id}` }));
}

function OrderModal({ order, onClose }) {
  const closeButton = useRef(null);
  useEffect(() => {
    const opener = document.activeElement;
    closeButton.current?.focus();
    const handleKeyDown = (event) => {
      if (event.key === "Escape") {
        event.preventDefault();
        onClose();
      } else if (event.key === "Tab") {
        event.preventDefault();
        closeButton.current?.focus();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      if (opener?.isConnected) opener.focus();
    };
  }, []);

  return <div className="order-modal-backdrop" style={modalBackdropStyle} onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
    <section className="order-modal" role="dialog" aria-modal="true" aria-label="Detalle del pedido" tabIndex={-1} style={modalPanelStyle}>
      <button ref={closeButton} type="button" onClick={onClose} aria-label="Cerrar detalle" style={{ float: "right" }}>Cerrar</button>
      <h2>{order.order_number || `Pedido #${order.id}`}</h2>
      <p><strong>Cliente:</strong> {order.customer_name} · {order.customer_phone}</p>
      {order.delivery_address && <p><strong>Destino:</strong> {order.delivery_address}</p>}
      <h3>Productos</h3>
      <ul>{(order.order_items || []).map((item) => <li key={item.id}>Producto #{item.product_id} × {item.quantity} <span>CLP {money.format(item.subtotal_clp)}</span></li>)}</ul>
    </section>
  </div>;
}

export function DashboardView({ orders = [], restaurants = [], loading = false, error = "", selectedOrderId = null, onSelect = () => {}, onClose = () => {} }) {
  const mappedOrders = orders.length && restaurants.length && !orders[0].restaurantName ? mapOrders(orders, restaurants) : orders;
  const selectedOrder = mappedOrders.find((order) => String(order.id) === String(selectedOrderId));
  if (loading) return <section className="dashboard-state" role="status">Cargando pedidos…</section>;
  if (error) return <section className="dashboard-state dashboard-error" role="alert">No se pudieron cargar los pedidos: {error}</section>;
  if (!mappedOrders.length) return <section className="dashboard-state">Todavía no hay pedidos</section>;
  return <section className="dashboard-shell" lang="es">
    <header className="dashboard-header">
      <div className="brand-lockup" aria-label="Niu Foods y Niu Sushi">
        <img className="brand-logo brand-logo-foods" src="/assets/niu-foods-logo.png" alt="Logotipo de Niu Foods" />
        <img className="brand-logo brand-logo-sushi" src="/assets/niu-sushi-logo.png" alt="Logotipo de Niu Sushi" />
      </div>
      <div className="dashboard-heading"><p className="eyebrow">Operaciones</p><h1>Pedidos</h1></div>
      <span className="order-count">Pedidos: {mappedOrders.length}</span>
    </header>
    <div className="dashboard-tools">
      <label className="search-label" htmlFor="order-search">Buscar pedidos</label>
      <input className="order-search" id="order-search" type="text" placeholder="Buscar pedidos..." aria-label="Buscar pedidos" />
    </div>
    <div className="order-list" aria-label="Listado de pedidos">
      {mappedOrders.map((order) => <button className={`order-card${String(selectedOrderId) === String(order.id) ? " selected" : ""}`} key={order.id} type="button" onClick={() => onSelect(order.id)} aria-pressed={String(selectedOrderId) === String(order.id)}>
        <span className="order-main"><strong>{order.order_number || `Pedido #${order.id}`}</strong><span>{order.restaurantName}</span><span>{order.delivery_address || order.restaurantName}</span></span>
        <span className="order-meta"><strong>CLP {money.format(order.total_clp)}</strong><span>{title(order.order_type)}</span><span>{timestamp(order.created_at)}</span></span>
        <span className={`status status-${order.dispatch_status || "unknown"}`}>{title(order.dispatch_status)}</span>
      </button>)}
    </div>
    {selectedOrder && <OrderModal order={selectedOrder} onClose={onClose} />}
  </section>;
}

function Dashboard() {
  const [orders, setOrders] = useState([]); const [restaurants, setRestaurants] = useState([]);
  const [loading, setLoading] = useState(true); const [error, setError] = useState(""); const [selectedOrderId, setSelectedOrderId] = useState(null);
  useEffect(() => {
    let active = true;
    const load = (url, key) => fetch(url).then((response) => { if (!response.ok) throw new Error(`${key}: error en la solicitud`); return response.json(); });
    Promise.all([load("/api/v1/orders", "Pedidos"), load("/api/v1/restaurants", "Restaurantes")])
      .then(([orderData, restaurantData]) => { if (active) { setOrders(orderData.orders || []); setRestaurants(restaurantData); setLoading(false); } })
      .catch(() => { if (active) { setError("No fue posible conectar con el servicio. Intenta nuevamente más tarde."); setLoading(false); } });
    return () => { active = false; };
  }, []);
  return <DashboardView orders={mapOrders(orders, restaurants)} loading={loading} error={error} selectedOrderId={selectedOrderId} onSelect={setSelectedOrderId} onClose={() => setSelectedOrderId(null)} />;
}

if (typeof document !== "undefined") {
  const mount = document.getElementById("orders-dashboard");
  if (mount) createRoot(mount).render(<Dashboard />);
}
