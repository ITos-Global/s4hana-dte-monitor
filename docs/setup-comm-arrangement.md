# Setup — Communication Arrangement para Posting de Facturas

Esta guía configura la integración HTTP custom → API_SUPPLIERINVOICE_PROCESS_SRV
para que `zcl_dte_processor=>contabilizar` pueda crear facturas de proveedor.

## Pre-condiciones

- Communication User existente (vamos a reusar `COM_MONITOR`).
- Rol del Communication User: necesita autorización para crear facturas
  (típicamente `SAP_BR_AP_ACCOUNTANT` o similar).

## Paso 1 — Verificar/Asignar rol al Communication User

1. Fiori → **Maintain Communication Users** → buscar `COM_MONITOR`.
2. Verificar que tiene asignado el business role:
   - `SAP_BR_AP_ACCOUNTANT_PROCSV` o
   - `SAP_BR_AP_ACCOUNTANT` o
   - Cualquier rol que incluya la app *Manage Supplier Invoices*.
3. Si falta, asignarlo en Fiori "Maintain Business Users".

## Paso 2 — Communication Arrangement

1. Fiori → **Communication Arrangements** → crear nueva.
2. **Scenario**: buscar y seleccionar `SAP_COM_0046`
   *(Supplier Invoice Integration)*.
3. **Arrangement Name**: dejar el default (`SAP_COM_0046_COM_MONITOR_...`)
   o renombrar a `ZCOM_DTE_POSTING`.
4. En **Common Data**:
   - **User Name** (Inbound): `COM_MONITOR`
   - **Authentication Method**: User ID and Password
5. En **Outbound Services**: (vacío — no usamos outbound de esta scenario)
6. En **Inbound Services**:
   - Habilitar `Supplier Invoice` (`API_SUPPLIERINVOICE_PROCESS_SRV`)
   - URL path se autogenera: `/sap/opu/odata/sap/API_SUPPLIERINVOICE_PROCESS_SRV`
7. **Save** y **Activate**.

## Paso 3 — Verificar conectividad

Desde Postman o curl, hacer un GET de prueba al servicio:

```
GET https://my419159-api.s4hana.cloud.sap/sap/opu/odata/sap/API_SUPPLIERINVOICE_PROCESS_SRV/A_SupplierInvoice?$top=1
Auth: Basic (COM_MONITOR / password)
```

Si devuelve 200 → ok. Si devuelve 403 → falta rol al CU. Si devuelve 404 → comm arrangement no se publicó.

## Paso 4 — Notar el endpoint resuelto

Para self-calls dentro del mismo S/4HANA Cloud, **no necesitamos** un
`cl_http_destination_provider` apuntando a otra URL. Usamos la API local
con la sesión del usuario.

En el código (`ZCL_DTE_HTTP_INVOICE`), la URL del API se construye así:

```abap
" Path relativo al host actual
DATA(lv_url) = '/sap/opu/odata/sap/API_SUPPLIERINVOICE_PROCESS_SRV/A_SupplierInvoice'.
```

Y se llama vía `cl_web_http_client_manager=>create_by_destination` con
una destination de tipo "internal" o usando el SDK de comunicación de
ABAP Cloud.

## Troubleshooting

| Error | Causa |
|---|---|
| HTTP 403 Forbidden | Communication User sin rol SAP_BR_AP_ACCOUNTANT |
| HTTP 404 | Communication Arrangement no activada o scenario incorrecto |
| HTTP 400 + "Field XYZ missing" | Payload incompleto — revisar required fields |
| HTTP 500 BEHAVIOR_INTERNAL_ACCESS | Estás usando MODIFY ENTITIES en vez de HTTP (no aplica aquí) |
