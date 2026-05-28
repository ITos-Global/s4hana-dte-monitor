# Runbook — Pruebas del Monitor DTE

Guía para ejecutar / reprocesar el plan de pruebas del Monitor DTE Proveedor.
Pensada para que un agente nuevo (o cualquier dev) pueda correr las pruebas sin
contexto previo.

---

## 1. Landscape (2 tenants — NO confundir)

| Rol | Tenant | Uso |
|-----|--------|-----|
| **Desarrollo ABAP** | `https://my419175.s4hana.cloud.sap` | Se edita/activa el código vía ADT (Eclipse o bridge MCP). Usuario dev `CB9980000114`. |
| **Pruebas / runtime OData** | `https://my419159.s4hana.cloud.sap` (API host `my419159-api`) | Corre `run_test_plan.py`. Usuario runtime `COM_MONITOR`. Usuario de UI/test `CB9980000213` **sin rol de desarrollo** (ADT da 403 al leer fuente). |

> El código activado en **dev (419175) NO aplica en pruebas (419159)** hasta que
> se **importa el transporte** en 419159. Activar en dev ≠ desplegar en pruebas.

---

## 2. Archivos del plan de pruebas (`docs/`)

| Archivo | Qué hace |
|---|---|
| `run_test_plan.py` | Orquestador: por cada caso hace `DELETE` → `IngestFromXml` → `IngestFromSii` → `GET`, y compara el log/estado con el resultado esperado. Escribe `test_run_results.json`. Credenciales runtime embebidas (host `my419159-api`, user `COM_MONITOR`). |
| `update_xlsx_results.py` | Vuelca `test_run_results.json` a la planilla (cols P/Q/R/S) con colores PASS/FAIL. |
| `test_run_results.json` | Resultado de la última corrida (se sobrescribe). |
| `XML/` | XMLs de los DTE de prueba (`PU <n> HES v<x>.xml`). |
| `Pruebas desarrollo monitor v1.xlsx` | Plan de pruebas (hoja `Servicios`). Col M = nombre del XML, col N = resultado esperado. |

---

## 3. Cómo correr las pruebas

```powershell
cd C:\DEV\S4HANA_MONITOR\docs

# Verificar conectividad al tenant de pruebas
python run_test_plan.py --smoke

# Correr casos específicos (ej. 14, 15 y 17)
python run_test_plan.py --only 14,15,17

# Correr todo el plan
python run_test_plan.py

# Volcar resultados a la planilla
python update_xlsx_results.py
```

- El número de caso `N` mapea a la **fila `N+1`** de la hoja `Servicios`
  (fila 1 = encabezados).
- El harness **borra el registro (DELETE) antes de re-ingestar**, así cada corrida
  parte limpia. Esto **requiere que `delete;` + la auth `%delete` estén activos en
  419159** (ver §6). Si el DELETE devuelve **405**, el `delete;` no está publicado.

---

## 4. Estados del monitor

| Cód | Etiqueta | Notas |
|-----|----------|-------|
| 01 | Pendiente | Recién ingestado. |
| 02 | Aprobado | Lo asigna el proceso del SII (fuera del monitor). |
| 03 | Rechazado | Terminal. |
| 04 | Por rechazar | Falló una validación de negocio (sociedad, OC, HES, monto, etc.). |
| 05 | No procesado | Pasó validaciones pero la contabilización (API factura) falló, o factura ya existente. |
| 06 | Contabilizado | Validó + se creó la factura vía API. (transitorio a 02 tras SII) |

> No existe estado "Validado". Al superar todas las validaciones, `process_dte`
> contabiliza automáticamente: OK → **06**, error API → **05**.

---

## 5. Flujo de deploy de cambios ABAP (dev → pruebas)

1. **Editar y activar en `my419175`** (Eclipse o bridge MCP `s4hana-adt`).
   - El bridge MCP **puede** escribir: fuente principal de clases (`CLAS`) y
     behavior definitions (`BDEF`, vía URI `/sap/bc/adt/bo/behaviordefinitions/<name>`).
   - El bridge MCP **NO puede** escribir los *includes locales* de clase (CCIMP/CCDEF,
     ej. el handler `lhc_*` del behavior pool) — fuerza una ruta `.../source/main`
     que no existe para includes. Esos cambios se hacen **a mano en Eclipse**
     (pestaña *Local Types*).
   - Activar requiere confirmación (entorno compartido). Si el bridge no puede
     activar, activar en Eclipse.
2. **Liberar la Software Collection** en dev (app *Export Software Collection*).
3. **Importar el transporte en `my419159`** (cola de transporte / Cloud Transport
   Management). **Sin este import el código no aplica en pruebas.**
4. Si el cambio afecta la metadata del servicio (ej. agregar `delete;`),
   **re-activar/re-publicar el Service Binding `ZUI_DTE_MONITOR_O4`** en 419159.

> ⚠️ **El `delete;` (u otra operación) NO se propaga solo de la interface a la projection.**
> El binding OData expone la **projection `ZC_DTE_MONITOR`**, no la interface `ZI_DTE_MONITOR`.
> Para exponer DELETE en OData hay que declararlo en AMBOS bdef:
> - `ZI_DTE_MONITOR` (interface): `delete;`
> - `ZC_DTE_MONITOR` (projection): `use delete;`  ← si falta, `Deletable=false` aunque la interface lo tenga.
> Luego activar la projection y **re-activar el Service Binding** para que la metadata lo refleje.

---

## 6. Verificar qué hay activo en `my419159` (sin auth de dev)

Como el usuario de pruebas no tiene rol de desarrollo (ADT → 403), se verifica por
**runtime**, no por fuente:

- **¿Está activo el `delete;`?** Consultar la metadata OData y mirar `Deletable`:
  ```powershell
  cd C:\DEV\S4HANA_MONITOR\docs
  python -c "import requests; from run_test_plan import URL,USER,PWD; s=requests.Session(); s.auth=(USER,PWD); t=s.get(URL+'/$metadata',timeout=30).text; print('Deletable=true' if 'Deletable\" Bool=\"true' in t else 'Deletable=false (DELETE NO publicado)')"
  ```
  `Deletable=false` → el `delete;` aún no está en el binding publicado (DELETE dará 405).
- **¿Está activo el fix del processor?** Correr el caso y mirar el log: si 14/15
  siguen con `Balance not zero` idéntico, el fix no se importó.

---

## 7. Conexión ADT con el bridge MCP (`s4hana-adt`)

- Conectar: `s4_connect` con la URL del tenant (modo `sso`, abre Chromium para login).
- **Cookie bloat / HTTP 431** ("request header too long"): pasa al cambiar de tenant
  porque el bridge cachea cookies. **Solución:** `s4_disconnect` de cada URL previa
  antes de re-conectar.
- Para **deploy** conectarse a `my419175`; para **inspección runtime** alcanza con
  los scripts (no requiere ADT).

---

## 8. Notas por caso (servicios / facturas con HES)

- **Caso 14** — "DTE con OC-HES moneda distinta a CLP": el XML `PU 14` **no trae
  `<TpoMoneda>`** → es CLP por defecto del SII. La moneda distinta está en la OC/HES.
  El fix en `contabilizar` arma el `SupplierInvoiceItemAmount` desde el **neto del DTE**
  (no desde la HES) y en la moneda del DTE, para que ítems + IVA auto cuadren con el bruto.
- **Caso 15** — "diferencia dentro de tolerancia": el bruto (DTE) difiere del neto HES;
  mismo fix de reconciliación hace que el débito (ítems+IVA del DTE) cuadre con el
  crédito (bruto DTE).
- **Caso 17** — "factura anulada": el XML debe ser `PU 17 HES v3` (MntNeto **100.000**,
  coincide con el saldo de la OC). Como `IngestFromXml` es solo-CREATE y `XmlData` es
  `readonly:update`, un registro viejo NO se refresca al re-ingestar → por eso el
  harness hace `DELETE` antes. Requiere `delete;`/`%delete` activos en 419159.

---

## 9. Checklist rápido para reprocesar

- [ ] Cambios ABAP activados en `my419175`.
- [ ] Transporte **importado** en `my419159`.
- [ ] Service Binding `ZUI_DTE_MONITOR_O4` republicado si cambió la metadata.
- [ ] `python run_test_plan.py --smoke` OK.
- [ ] Metadata `Deletable=true` (si se prueba el DELETE / caso 17).
- [ ] `python run_test_plan.py --only <casos>`.
- [ ] `python update_xlsx_results.py`.
- [ ] Revisar `Pruebas desarrollo monitor v1.xlsx` (cols P/Q/R/S).
