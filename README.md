# Órdenes Niufoods

Aplicación Rails para recibir, validar, persistir y despachar órdenes. Esta guía permite levantar el dashboard y el worker con Docker Compose, cargar datos de prueba y recorrer el flujo completo sin una tienda externa.

## Inicio rápido para revisar

Requisitos: Docker Engine y Docker Compose.

1. Desde la raíz del repositorio, iniciá PostgreSQL, Redis, la aplicación web y Sidekiq:

   ```sh
   docker compose up --build
   ```

   La primera ejecución construye la imagen y puede tardar unos minutos. Rails prepara las bases de datos al iniciar el servidor.

2. En otra terminal, cargá el catálogo de prueba:

   ```sh
   docker compose exec web ./bin/rails db:seed
   ```

3. Abrí el dashboard en [http://localhost:3000](http://localhost:3000). El servicio `web` sirve la API, el endpoint de tienda simulada y los assets compilados del dashboard.

4. Generá cinco órdenes de ejemplo desde la raíz del repositorio:

   ```sh
   ruby script/order_simulator.rb --count 5
   ```

   El simulador envía órdenes a `http://localhost:3000/api/v1/orders` con claves de idempotencia únicas. Usa los restaurantes 1–3 y productos 1–10 que carga el seed. También podés crear órdenes manualmente con el ejemplo de Postman más abajo.

5. Revisá el procesamiento del worker y las órdenes:

   ```sh
   docker compose logs -f worker
   curl -sS http://localhost:3000/api/v1/orders
   ```

   El listado devuelve `{ "orders": [...] }`. Una orden aceptada se encola en Redis y el worker la envía al endpoint simulado; normalmente termina con `dispatch_status: "sent"`. Si el despacho todavía está pendiente, consultá el listado de nuevo.

Para detener los servicios, usá `Ctrl+C` en la terminal de Compose. También podés ejecutar `docker compose down`. Para borrar además las bases de datos y el estado de Redis y comenzar desde cero:

```sh
docker compose down -v
```

> `down -v` elimina permanentemente los volúmenes locales de PostgreSQL y Redis.

## Crear una orden con Postman o curl

Configurá en Postman una solicitud `POST` a `http://localhost:3000/api/v1/orders` con estos headers:

| Header | Valor |
|---|---|
| `Content-Type` | `application/json` |
| `Idempotency-Key` | `postman-reviewer-001` |

En **Body → raw → JSON**, enviá:

```json
{
  "order": {
    "restaurant_id": 1,
    "order_type": "pickup",
    "customer_name": "Ada Lovelace",
    "customer_phone": "555-0100",
    "items": [
      { "product_id": 1, "quantity": 2 }
    ]
  }
}
```

La primera solicitud con esa clave devuelve `201 Created` y un JSON `{ "order": { ... } }` con la orden persistida, sus ítems, el total calculado por el servidor y el estado de despacho. Repetir el mismo payload con el mismo `Idempotency-Key` devuelve `200 OK` y la orden existente, sin crear otra orden ni encolar otro despacho. Usá una clave nueva para cada orden distinta. Si el catálogo todavía no está cargado o el payload no es válido, la API responde `422 Unprocessable Entity` con `{ "errors": [...] }`.

El mismo ejemplo con curl:

```sh
curl -i -X POST http://localhost:3000/api/v1/orders \
  -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: postman-reviewer-001' \
  -d '{"order":{"restaurant_id":1,"order_type":"pickup","customer_name":"Ada Lovelace","customer_phone":"555-0100","items":[{"product_id":1,"quantity":2}]}}'
```

## Endpoints útiles

| Método y ruta | Uso |
|---|---|
| `GET /api/v1/restaurants` | Consultar restaurantes activos |
| `GET /api/v1/products` | Consultar productos activos |
| `POST /api/v1/orders` | Crear una orden idempotente |
| `GET /api/v1/orders` | Listar órdenes y su estado de despacho |
| `GET /api/v1/orders/:id` | Consultar una orden |
| `POST /store_api/v1/orders` | Endpoint local simulado para recibir despachos |
| `GET /up` | Health check de Rails |

## Cómo funciona el despacho

1. Rails valida la clave de idempotencia, el restaurante, los productos y las cantidades.
2. La orden y sus ítems se guardan en PostgreSQL; el total se calcula con los precios del catálogo.
3. Sidekiq toma el job desde Redis y envía la orden al endpoint local simulado.
4. La API simula una aceptación `201`; Rails actualiza `dispatch_status` y los campos de seguimiento. Sidekiq reintenta fallos de transporte y respuestas HTTP reintentables.

El worker usa la dirección interna de Compose para llamar al servicio `web`. No hace falta configurar una tienda externa.

## Verificación

La suite Rails configurada para el proyecto se ejecuta localmente con Ruby 4.0.7:

```sh
PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test
```

El dashboard usa React; su bundle ya está incluido en `public/assets`. Para recompilarlo después de modificar su fuente, ejecutá `npm ci && npm run build`.

## Arquitectura y reglas del proyecto

- Monolito modular construido con Ruby on Rails; PostgreSQL es la fuente de persistencia.
- React renderiza el dashboard; Sidekiq y Redis gestionan el despacho asíncrono y los reintentos.
- Minitest cubre la aplicación y el simulador Ruby genera órdenes con claves idempotentes únicas.
- La idempotencia evita duplicar órdenes y jobs cuando se repite una solicitud con la misma clave.
- Los totales se calculan en el servidor y los precios de los ítems se guardan como snapshots históricos.
- Los errores HTTP 5xx, throttling y fallos de transporte se reintentan; los errores definitivos 4xx terminan con estado `error`.
