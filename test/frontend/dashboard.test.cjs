const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const zlib = require('node:zlib');
const React = require('react');
const { renderToStaticMarkup } = require('react-dom/server');
const { DashboardView, mapOrders } = require('../../tmp/dashboard.cjs');

const orders = [{ id: 7, order_number: 'ORD-7', restaurant_id: 2, order_type: 'delivery', customer_name: 'Ada', customer_phone: '123', delivery_address: 'Main 5', total_clp: 12500, dispatch_status: 'pending', created_at: '2026-09-30T12:00:00Z', order_items: [{ id: 1, product_id: 4, quantity: 2, unit_price_clp: 6250, subtotal_clp: 12500 }] }];
const restaurants = [{ id: 2, name: 'Niu Providencia' }];
const html = (props) => renderToStaticMarkup(React.createElement(DashboardView, props));

function pngHasTransparentPixels(path) {
  const png = fs.readFileSync(path);
  assert.equal(png.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
  assert.equal(png[25], 6, 'PNG must have RGBA pixels');
  const width = png.readUInt32BE(16);
  const height = png.readUInt32BE(20);
  const chunks = [];
  for (let offset = 8; offset < png.length;) {
    const length = png.readUInt32BE(offset);
    const name = png.toString('ascii', offset + 4, offset + 8);
    if (name === 'IDAT') chunks.push(png.subarray(offset + 8, offset + 8 + length));
    offset += length + 12;
  }
  const data = zlib.inflateSync(Buffer.concat(chunks));
  const stride = width * 4;
  let previous = Buffer.alloc(stride);
  let transparent = false;
  const paeth = (a, b, c) => {
    const p = a + b - c;
    const distances = [Math.abs(p - a), Math.abs(p - b), Math.abs(p - c)];
    return distances.indexOf(Math.min(...distances)) === 0 ? a : distances.indexOf(Math.min(...distances)) === 1 ? b : c;
  };
  for (let y = 0; y < height; y++) {
    const start = y * (stride + 1);
    const filter = data[start];
    const row = Buffer.alloc(stride);
    for (let i = 0; i < stride; i++) {
      const raw = data[start + 1 + i];
      const left = i >= 4 ? row[i - 4] : 0;
      const up = previous[i];
      const upperLeft = i >= 4 ? previous[i - 4] : 0;
      const predictor = filter === 1 ? left : filter === 2 ? up : filter === 3 ? Math.floor((left + up) / 2) : filter === 4 ? paeth(left, up, upperLeft) : 0;
      row[i] = (raw + predictor) & 255;
    }
    for (let alpha = 3; alpha < stride; alpha += 4) if (row[alpha] === 0) transparent = true;
    previous = row;
  }
  return transparent;
}

test('maps restaurant and required operational fields in Spanish', () => {
  const mapped = mapOrders(orders, restaurants);
  assert.equal(mapped[0].restaurantName, 'Niu Providencia');
  const markup = html({ orders: mapped });
  for (const label of ['ORD-7', 'Niu Providencia', '12.500', 'A domicilio', 'Pendiente', 'Operaciones', 'Pedidos']) assert.match(markup, new RegExp(label));
  assert.doesNotMatch(markup, /\b(Orders|Delivery|Pending|Customer|Destination|Products|Unknown)\b/);
  assert.match(html({ orders: mapOrders([{ ...orders[0], order_type: 'pickup', dispatch_status: 'other' }], restaurants) }), /Retiro en local/);
  assert.match(html({ orders: mapOrders([{ ...orders[0], dispatch_status: 'other' }], restaurants) }), /Desconocido/);
});

test('renders Spanish loading, empty, and error states', () => {
  assert.match(html({ loading: true }), /Cargando pedidos/);
  assert.match(html({ orders: [] }), /Todavía no hay pedidos/);
  assert.match(html({ error: 'Servicio no disponible' }), /No se pudieron cargar los pedidos: Servicio no disponible/);
});

test('selected order reveals customer and item details in Spanish', () => {
  const markup = html({ orders: mapOrders(orders, restaurants), selectedOrderId: 7 });
  assert.match(markup, /Ada/);
  assert.match(markup, /Producto #4/);
  assert.match(markup, /Main 5/);
  assert.match(markup, /aria-label="Detalle del pedido"/);
});

test('uses official transparent brand logos and an inert text search field', () => {
  const markup = html({ orders: mapOrders(orders, restaurants) });
  assert.match(markup, /<img[^>]+src="\/assets\/niu-foods-logo\.png"[^>]+alt="Logotipo de Niu Foods"/);
  assert.match(markup, /<img[^>]+src="\/assets\/niu-sushi-logo\.png"[^>]+alt="Logotipo de Niu Sushi"/);
  assert.match(markup, /<input[^>]+type="text"[^>]+placeholder="Buscar pedidos\.\.\."[^>]+aria-label="Buscar pedidos"/);
  assert.doesNotMatch(markup, /<form\b|onChange=/);
  const source = fs.readFileSync('app/javascript/dashboard.jsx', 'utf8');
  const searchInput = source.match(/<input className="order-search"[^>]+\/>/)[0];
  assert.match(searchInput, /type="text"/);
  assert.doesNotMatch(searchInput, /on[A-Z]|value=|disabled|readOnly/);
  assert.doesNotMatch(source, /setSearch|searchTerm|orders\.filter/);
  assert.equal((markup.match(/class="order-card/g) || []).length, 1);
  assert.equal(pngHasTransparentPixels('public/assets/niu-foods-logo.png'), true);
  assert.equal(pngHasTransparentPixels('public/assets/niu-sushi-logo.png'), true);
  const css = fs.readFileSync('public/assets/orders-dashboard.css', 'utf8');
  for (const color of ['#ef1010', '#232227', '#29282d', '#2e2c30', '#333235', '#fff', '#b70a0a']) assert.ok(css.toLowerCase().includes(color));
  const logoRule = css.match(/\.brand-logo\s*\{([^}]+)\}/)[1];
  assert.match(logoRule, /max-height:\s*clamp\(/);
  assert.match(logoRule, /max-width:\s*min\(/);
  assert.match(logoRule, /object-fit:\s*contain/);
  assert.match(css, /\.order-search:hover/);
  assert.match(css, /\.order-search:focus-visible/);
});
