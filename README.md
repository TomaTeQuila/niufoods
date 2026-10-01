# Órdenes Niufoods

Prueba técnica para recibir, validar, persistir y despachar órdenes de comida al restaurante correspondiente.

## Estado actual

La aplicación recibe órdenes en Rails, las persiste en PostgreSQL y las despacha en segundo plano mediante Sidekiq y Redis. El endpoint local de tienda simulada permite probar el recorrido completo sin integrar una tienda externa.

## Decisiones de arquitectura

- Monolito modular construido con Ruby on Rails.
- PostgreSQL para la persistencia de datos.
- React para la interfaz del dashboard.
- Sidekiq y Redis para el despacho asíncrono y los reintentos.
- Minitest para las pruebas automatizadas.
- Idempotencia mediante el header `Idempotency-Key`.
- Endpoint de tienda simulada para probar el despacho de órdenes.
- Docker Compose para el entorno de desarrollo local.

Se seleccionó el monolito porque el flujo actual de órdenes es cohesivo y no requiere dominios de negocio desplegables de forma independiente. Se mantendrán límites internos explícitos para que una futura integración con tiendas o un módulo de despacho pueda extraerse si las necesidades reales de escalamiento lo justifican.

## Ejecutar localmente

1. Iniciá PostgreSQL y Redis. El archivo [`docker-compose.yml`](docker-compose.yml) provee ambos servicios:

   ```sh
   docker compose up -d postgres redis
   ```

2. Prepará la base y cargá el catálogo de prueba:

   ```sh
   export DATABASE_HOST=127.0.0.1 DATABASE_PORT=5433 DATABASE_USER=niufoods DATABASE_PASSWORD=niufoods
   export REDIS_URL=redis://localhost:6379/0
   PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails db:prepare db:seed
   ```

3. En terminales separadas, iniciá la aplicación web y el worker:

   ```sh
   export DATABASE_HOST=127.0.0.1 DATABASE_PORT=5433 DATABASE_USER=niufoods DATABASE_PASSWORD=niufoods REDIS_URL=redis://localhost:6379/0
   PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails server
   ```

   En una segunda terminal, exportá las mismas variables y ejecutá:

   ```sh
   export DATABASE_HOST=127.0.0.1 DATABASE_PORT=5433 DATABASE_USER=niufoods DATABASE_PASSWORD=niufoods REDIS_URL=redis://localhost:6379/0
   PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bundle exec sidekiq -C config/sidekiq.yml
   ```

   En producción, Kamal ejecuta el worker como proceso separado; `REDIS_URL` debe estar configurado como secreto para ambos procesos.

## Probar el despacho

Creá una orden nueva con una clave de idempotencia única. Reemplazá los IDs si tu catálogo usa otros:

```sh
curl -i -X POST http://localhost:3000/api/v1/orders \
  -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: local-dispatch-001' \
  -d '{"order":{"restaurant_id":1,"order_type":"pickup","customer_name":"Ada","customer_phone":"555-0100","items":[{"product_id":1,"quantity":2}]}}'
```

Una orden nueva devuelve `201`; repetir el mismo `Idempotency-Key` devuelve `200` y no agrega otro job. Sidekiq registra el procesamiento en la terminal del worker. Consultá `GET /api/v1/orders` para verificar `dispatch_status`, `dispatch_attempts`, `last_dispatch_error` y `dispatched_at`.

La tienda simulada recibe `POST /store_api/v1/orders`. El despacho usa `restaurants.dispatch_url` cuando está definido; si no, usa `STORE_API_URL` o el endpoint local por defecto. El cliente manda `Idempotency-Key` estable basado en `order_number`, apropiado para un worker con entrega al menos una vez.

## Endpoints

```text
POST /api/v1/orders
GET  /api/v1/orders
GET  /api/v1/orders/:id
```

Endpoint de tienda simulada:

```text
POST /store_api/v1/orders
```

La API devuelve órdenes en JSON; el endpoint simulado responde `201` con estado `accepted` cuando recibe un `order_number` válido.

## Flujo de despacho

1. Un canal digital o el simulador Ruby envía una orden a la API Rails.
2. Rails valida el payload y la clave de idempotencia.
3. La orden y sus ítems se persisten transaccionalmente en PostgreSQL.
4. Un job de despacho se encola en Redis.
5. Sidekiq envía la orden a la tienda simulada.
6. El estado de despacho se actualiza a `sent` o `error`.
7. Los despachos fallidos se reintentan según la configuración de Sidekiq.

## Verificación

```sh
PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test
```

## Reglas del proyecto

- Los totales se calculan en el servidor utilizando los precios de productos almacenados en PostgreSQL.
- Los precios de los ítems se guardan como snapshots históricos.
- Las solicitudes duplicadas que utilicen la misma clave de idempotencia no deben crear órdenes duplicadas ni encolar otro despacho.
- Los errores HTTP 5xx, throttling y fallos de transporte se reintentan; los errores definitivos 4xx terminan con estado `error`.
