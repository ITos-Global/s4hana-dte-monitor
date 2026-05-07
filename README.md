# Monitor DTE Proveedor — S/4HANA + SAPUI5 + SAP BTP CF

Monitor de Documentos Tributarios Electrónicos (DTE) de proveedores para **Fenix Gold / Lince SA** (Chile).

## Descripción

El sistema valida y contabiliza automáticamente los DTE (Facturas, NC, ND) recibidos de proveedores contra documentos de referencia en S/4HANA (OC, HES, Entrada de Mercancías). Expone un monitor SAPUI5 para revisión manual, reproceso y rechazo.

## Arquitectura

```
SAP BTP Cloud Foundry
  └── SAPUI5 App (monitordte)  ← HTML5 Repo + Managed App Router
        └── OData V4 (ZUI_DTE_MONITOR_O4)
              └── S/4HANA Public Edition (RAP + CDS)
```

## Estructura del repositorio

```
├── src/                          # Backend ABAP (abapgit)
│   ├── zdte_monitor.tabl.asddls      Tabla principal DTE
│   ├── zdte_monitor_h.tabl.asddls    Tabla historial/tracking
│   ├── zdte_config.tabl.asddls       Tabla de configuración
│   ├── ZI_DTE_MONITOR.ddls.asddls    CDS Interface View
│   ├── ZI_DTE_MONITOR_H.ddls.asddls  CDS Historial View
│   ├── ZC_DTE_MONITOR.ddls.asddls    CDS Projection View (UI)
│   ├── ZC_DTE_MONITOR.ddlx.asddlxs   Metadata Extensions (UI annotations)
│   ├── ZC_DTE_MONITOR_H.ddls.asddls  CDS Historial Projection
│   ├── ZS_DTE_DOC_REF.ddls.asddls    Estructura parámetro IndicarDocReferencia
│   ├── ZS_DTE_POSICION.ddls.asddls   Estructura parámetro IndicarPosiciones
│   ├── ZS_DTE_RECHAZO.ddls.asddls    Estructura parámetro Rechazar
│   ├── ZI_DTE_MONITOR.dcl.asdcls     Access Control (PFCG por Sociedad)
│   ├── ZI_DTE_MONITOR.bdef.asbdef    Behavior Definition RAP
│   ├── ZBP_I_DTE_MONITOR.clas.abap   Behavior Implementation Class
│   ├── ZCL_DTE_PROCESSOR.clas.abap   Clase procesamiento/validación DTE
│   └── ZUI_DTE_MONITOR.srvd.assdls   Service Definition OData V4
│
├── app/monitordte/               # Frontend SAPUI5 (deploy BTP)
│   └── webapp/
│       ├── manifest.json
│       ├── Component.js
│       ├── view/
│       │   ├── Main.view.xml
│       │   ├── DocRef.fragment.xml
│       │   └── Posiciones.fragment.xml
│       ├── controller/Main.controller.js
│       ├── formatter/formatter.js
│       └── i18n/i18n.properties
│
├── mta.yaml                      # MTA descriptor (deploy BTP CF)
├── xs-security.json              # XSUAA scopes y roles
├── xs-app.json                   # App Router routing rules
└── .abapgit.xml                  # Configuración abapgit
```

## Implementación ABAP (abapgit)

### Pre-requisitos
- S/4HANA Public Edition con acceso ADT
- abapgit instalado (ver [abapgit.org](https://abapgit.org))
- Paquete Z creado en SAP (ej. `ZDTE_MONITOR`)

### Pasos
1. En abapgit → **New Online** → URL de este repositorio
2. Asignar al paquete `ZDTE_MONITOR` (o el paquete que corresponda)
3. Seleccionar rama `main`
4. **Pull** — abapgit lee todos los objetos de `/src/`
5. Activar objetos en el orden:
   1. Tablas (`zdte_monitor`, `zdte_monitor_h`, `zdte_config`)
   2. CDS Interface Views (`ZI_DTE_MONITOR`, `ZI_DTE_MONITOR_H`)
   3. Access Control (`ZI_DTE_MONITOR.dcl`)
   4. Behavior Definition (`ZI_DTE_MONITOR.bdef`)
   5. Estructuras de parámetros (`ZS_DTE_*`)
   6. CDS Projection Views (`ZC_DTE_MONITOR`, `ZC_DTE_MONITOR_H`)
   7. Metadata Extensions (`ZC_DTE_MONITOR.ddlx`)
   8. Service Definition (`ZUI_DTE_MONITOR`)
   9. Clases ABAP (`ZBP_I_DTE_MONITOR`, `ZCL_DTE_PROCESSOR`)
6. Crear Service Binding `ZUI_DTE_MONITOR_O4` (OData V4 - UI) manualmente en ADT y publicar

### Estados DTE

| Código | Descripción    | Color     |
|--------|----------------|-----------|
| 01     | Pendiente      | Warning   |
| 02     | Aprobado       | Success   |
| 03     | Rechazado      | Error     |
| 04     | Por rechazar   | Error     |
| 05     | No procesado   | Error     |
| 06     | Contabilizado  | Success   |

### Tolerancias de monto (ZDTE_CONFIG)

| Parámetro       | Valor inicial | Descripción                              |
|----------------|---------------|------------------------------------------|
| TOL_PORCENTAJE  | 5             | Tolerancia en % sobre monto OC           |
| TOL_MONTO_CLP   | TBD           | Tolerancia en monto absoluto CLP         |

## Implementación Frontend (BTP Cloud Foundry)

### Pre-requisitos
- Node.js ≥ 18 + MTA Build Tool (`npm install -g mbt`)
- CF CLI (`cf login`)
- Servicios BTP: XSUAA, HTML5 Repo, Destination

### Deploy

```bash
# Instalar dependencias
cd app/monitordte && npm ci && cd ../..

# Build MTA
mbt build

# Deploy
cf deploy mta_archives/dte-monitor_1.0.0.mtar
```

### Configuración Destination (BTP Cockpit)

| Propiedad                | Valor                                        |
|--------------------------|----------------------------------------------|
| Name                     | `ZMONITOR`                                   |
| Type                     | HTTP                                         |
| URL                      | `https://<tenant>.s4hana.ondemand.com`       |
| Authentication           | SAMLAssertion (Principal Propagation)        |
| HTML5.DynamicDestination | true                                         |

## Documentación

Ver `S&P - Diseño Tecnico Funcional Monitor DTE Proveedor v1.docx` para la especificación funcional completa.
