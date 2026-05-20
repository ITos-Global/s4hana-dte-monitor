# Guía de variables — Postman collection

Al importar la colección en Postman, abrí su pestaña **Variables** y ajustá los valores.

## ★ Variables de negocio (debes ajustar)

| Variable | Default | Descripción |
|---|---|---|
| `{{tipoDte}}` | `033` | ★ Tipo DTE: 033 Factura Afecta · 034 Factura Exenta · 046 Factura Compra · 056 Nota Débito · 061 Nota Crédito |
| `{{folio}}` | `1234009` | ★ Folio del DTE (único por TipoDte+Proveedor) |
| `{{proveedorRut}}` | `76543210-9` | ★ RUT del proveedor con dígito verificador, formato chileno |
| `{{sociedadRut}}` | `76188363-1` | ★ RUT receptor (sociedad del cliente Fenix Gold / Lince SA) |
| `{{ordenCompra}}` | `4500012345` | ★ Número de Orden de Compra SAP (NB - 10 dígitos) |
| `{{hes}}` | `1000000123` | ★ Hoja Entrada Servicios (cuando aplica) |
| `{{em}}` | `5000000456` | ★ Entrada Mercancía (cuando aplica) |
| `{{materialDocRef}}` | `5000000999` | ★ Documento Material referenciado (solo NC Devolución) |
| `{{materialDocRefAnio}}` | `2026` | ★ Año del Documento Material referenciado |
| `{{folioFacturaBase}}` | `1234000` | ★ Folio de la factura base (solo NC 61 / ND 56) que aparece en TpoDocRef=33|34 |
| `{{fechaDocumento}}` | `2026-05-10` | ★ Fecha de emisión del DTE (formato AAAA-MM-DD) |
| `{{fechaRecepcionSii}}` | `2026-05-17` | ★ Fecha de recepción del SII (dispara el procesamiento) |
| `{{moneda}}` | `CLP` | Moneda del DTE (default CLP) |
| `{{montoTotal}}` | `1785000` | ★ Monto total del DTE |
| `{{montoNeto}}` | `1500000` | ★ Monto neto del DTE |
| `{{iva}}` | `285000` | ★ IVA del DTE (19%) |

## Variables técnicas (no tocar normalmente)

| Variable | Default | Descripción |
|---|---|---|
| `{{baseUrl}}` | `https://my419159.s4hana.cloud.sap/sap/opu/odata4/sap/zui_dte…` | URL completa del servicio OData V4. Cambiar 'my419159' por el tenant SAP correcto. |
| `{{user}}` | `` | Usuario SAP / Communication User (Basic Auth) |
| `{{password}}` | `` | Password (Basic Auth) |
| `{{csrfToken}}` | `` | Se rellena automáticamente con el request 'Setup ▸ Fetch CSRF Token' |
| `{{cookies}}` | `` | Cookies de sesión (Postman las maneja en cookie jar) |
| `{{xmlDte}}` | `<?xml version="1.0" encoding="UTF-8"?><DTE><Encabezado><IdDo…` | Plantilla XML del DTE — reemplaza placeholders con las variables anteriores. Editable si necesitás otro escenario. |
