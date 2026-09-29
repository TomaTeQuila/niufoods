# Órdenes Niufoods

Prueba técnica para recibir, validar, persistir y despachar órdenes de comida al restaurante correspondiente.

## Estado actual

El proyecto se encuentra actualmente en la fase de arquitectura y configuración del entorno. El código de la aplicación todavía no ha sido implementado.

Documentación completada:

- Diagrama de arquitectura monolítica.
- Diagrama entidad-relación.
- Diagrama del esquema de base de datos.
- Diagrama de secuencia de una orden.

La documentación está disponible en [`docs/`](docs/).

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

## Entorno verificado

Las siguientes versiones fueron verificadas durante la configuración inicial:

| Herramienta | Versión | Estado |
| --- | --- | --- |
| Docker Engine | 29.4.0 | Instalado y ejecutándose |
| Docker Compose | v5.1.1 | Instalado |
| Ruby | 4.0.7 | Seleccionado para este proyecto mediante rbenv |
| rbenv | 1.3.2 | Instalado y configurado |
| Ruby on Rails | 8.1.4 | Instalado |

La aplicación Rails todavía no ha sido inicializada.

PostgreSQL y Redis se ejecutarán mediante Docker Compose. Las instalaciones locales de PostgreSQL y Redis no serán necesarias para la configuración final.

## Componentes planificados

- API Rails para crear y consultar órdenes.
- Módulo de órdenes para validación, cálculo de totales y persistencia.
- Módulo de despacho para comunicarse con la tienda simulada.
- Worker Sidekiq para el despacho en segundo plano y los reintentos.
- Dashboard React para visualizar las órdenes.
- Script Ruby para generar órdenes de prueba.

## API planificada

```text
POST /api/v1/orders
GET  /api/v1/orders
GET  /api/v1/orders/:id
```

Endpoint de tienda simulada:

```text
POST /store_api/v1/orders
```

Los payloads, las respuestas, las instrucciones de instalación y los comandos de ejecución se agregarán después de inicializar la aplicación Rails.

## Flujo de órdenes planificado

1. Un canal digital o el simulador Ruby envía una orden a la API Rails.
2. Rails valida el payload y la clave de idempotencia.
3. La orden y sus ítems se persisten transaccionalmente en PostgreSQL.
4. Un job de despacho se encola en Redis.
5. Sidekiq envía la orden a la tienda simulada.
6. El estado de despacho se actualiza a `sent` o `error`.
7. Los despachos fallidos se reintentan según la configuración de Sidekiq.

## Comandos de desarrollo

Los comandos finales se documentarán una vez creadas la aplicación y la configuración de Docker Compose.

## Reglas del proyecto

- El código de la aplicación no incluirá comentarios.
- Los totales se calculan en el servidor utilizando los precios de productos almacenados en PostgreSQL.
- Los precios de los ítems se guardan como snapshots históricos.
- Las solicitudes duplicadas que utilicen la misma clave de idempotencia no deben crear órdenes duplicadas.
