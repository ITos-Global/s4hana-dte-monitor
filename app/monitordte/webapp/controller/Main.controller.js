sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/ui/model/json/JSONModel",
    "sap/m/MessageBox",
    "sap/m/MessageToast",
    "sap/ui/export/Spreadsheet",
    "sap/ui/export/library",
    "com/fenixgold/dte/monitordte/formatter/formatter"
], function (Controller, JSONModel, MessageBox, MessageToast, Spreadsheet, exportLibrary, formatter) {
    "use strict";

    const EdmType = exportLibrary.EdmType;

    // Estados que bloquean acciones de reproceso/rechazo
    const ESTADO_BLOQUEADO = ["02", "06"];
    // Estado que habilita indicar doc. ref. y posiciones
    const ESTADO_POR_RECHAZAR = "04";

    return Controller.extend("com.fenixgold.dte.monitordte.controller.Main", {

        formatter: formatter,

        // =====================================================================
        // LIFECYCLE
        // =====================================================================
        onInit: function () {
            this._initDocRefModel();
            this._initPosicionesModel();
            this._selectedContext = null;
            this._selectedContexts = [];
        },

        // =====================================================================
        // BÚSQUEDA
        // =====================================================================
        onSearch: function () {
            const oTable = this.byId("monitorTable");
            oTable.rebindTable(true);
        },

        // =====================================================================
        // SELECCIÓN DE FILAS — habilita/deshabilita botones dinámicamente
        // =====================================================================
        onRowSelectionChange: function () {
            const oInnerTable = this.byId("monitorTable").getTable();
            const aIndices    = oInnerTable.getSelectedIndices();
            const oBinding    = oInnerTable.getBinding("rows");

            if (!oBinding || aIndices.length === 0) {
                this._resetButtons();
                this._selectedContexts = [];
                this._selectedContext  = null;
                return;
            }

            // Recopilar contextos OData V4 de las filas seleccionadas
            this._selectedContexts = aIndices.map(i => oBinding.getContexts()[i]).filter(Boolean);
            this._selectedContext  = this._selectedContexts[0] || null;

            const aEstados    = this._selectedContexts.map(ctx => ctx.getProperty("Estado"));
            const bSingle     = this._selectedContexts.length === 1;
            const bBloqueados = aEstados.every(e => ESTADO_BLOQUEADO.includes(e));
            const bPorRech    = bSingle && aEstados[0] === ESTADO_POR_RECHAZAR;

            this.byId("btnReprocesar").setEnabled(!bBloqueados);
            this.byId("btnRechazar").setEnabled(!bBloqueados);
            this.byId("btnVerPdf").setEnabled(bSingle);
            this.byId("btnDocRef").setEnabled(bPorRech);
            this.byId("btnPosiciones").setEnabled(bPorRech);
        },

        // =====================================================================
        // ACCIÓN: Reprocesar
        // Invoca la bound action RAP Reprocesar sobre los registros seleccionados.
        // =====================================================================
        onReprocesar: function () {
            const aCtxs = this._selectedContexts.filter(
                ctx => !ESTADO_BLOQUEADO.includes(ctx.getProperty("Estado"))
            );

            if (!aCtxs.length) {
                MessageToast.show(this._i18n("msgNoSelection"));
                return;
            }

            MessageBox.confirm(this._i18n("msgConfirmReprocesar"), {
                title: this._i18n("btnReprocesar"),
                onClose: async (sAction) => {
                    if (sAction !== MessageBox.Action.OK) return;
                    this._setBusy(true);
                    try {
                        await Promise.all(
                            aCtxs.map(ctx =>
                                ctx.requestObject().then(() =>
                                    ctx.getModel().bindContext(
                                        "Reprocesar(...)",
                                        ctx
                                    ).execute()
                                )
                            )
                        );
                        MessageToast.show(this._i18n("msgReprocesarOk"));
                        this._refreshTable();
                    } catch (oErr) {
                        MessageBox.error(
                            this._i18n("msgReprocesarError") + "\n" + this._getErrorText(oErr)
                        );
                    } finally {
                        this._setBusy(false);
                    }
                }
            });
        },

        // =====================================================================
        // ACCIÓN: Rechazar
        // =====================================================================
        onRechazar: function () {
            const aCtxs = this._selectedContexts.filter(
                ctx => !ESTADO_BLOQUEADO.includes(ctx.getProperty("Estado"))
            );
            if (!aCtxs.length) return;

            MessageBox.confirm(this._i18n("msgConfirmRechazar"), {
                title: this._i18n("btnRechazar"),
                initialFocus: MessageBox.Action.CANCEL,
                actions: [MessageBox.Action.OK, MessageBox.Action.CANCEL],
                onClose: async (sAction) => {
                    if (sAction !== MessageBox.Action.OK) return;

                    // Pedir motivo de rechazo
                    const sMotivo = await this._promptMotivo();
                    if (sMotivo === null) return; // usuario canceló

                    this._setBusy(true);
                    try {
                        await Promise.all(
                            aCtxs.map(ctx => {
                                const oActionBinding = ctx.getModel().bindContext(
                                    "Rechazar(...)", ctx
                                );
                                oActionBinding.setParameter("Motivo", sMotivo);
                                return oActionBinding.execute();
                            })
                        );
                        MessageToast.show(this._i18n("msgRechazarOk"));
                        this._refreshTable();
                    } catch (oErr) {
                        MessageBox.error(this._getErrorText(oErr));
                    } finally {
                        this._setBusy(false);
                    }
                }
            });
        },

        // =====================================================================
        // ACCIÓN: Indicar Documento de Referencia
        // Abre el diálogo DocRef con los datos actuales del registro.
        // =====================================================================
        onIndicarDocRef: function () {
            if (!this._selectedContext) return;

            // Pre-poblar con valores existentes en el registro
            const oData = this._selectedContext.getObject();
            this.getView().getModel("docRefModel").setData({
                OrdenCompra:          oData.OrdenCompra          || "",
                HojaEntradaServicio:  oData.HojaEntradaServicio  || "",
                EntradaMercancia:     oData.EntradaMercancia      || "",
                AnioEntradaMercancia: oData.AnioEntradaMercancia  || "",
                FolioReferencia:      oData.FolioReferencia       || "",
                isValid:              false
            });

            this._openDocRefDialog();
        },

        onDocRefFieldChange: function () {
            const oModel = this.getView().getModel("docRefModel");
            const oData  = oModel.getData();
            // Al menos uno de los campos de referencia debe estar informado
            const bValid = !!(oData.OrdenCompra || oData.HojaEntradaServicio ||
                              oData.EntradaMercancia || oData.FolioReferencia);
            oModel.setProperty("/isValid", bValid);
        },

        onConfirmDocRef: async function () {
            const oData = this.getView().getModel("docRefModel").getData();
            this._setBusy(true);
            try {
                const oActionBinding = this._selectedContext.getModel().bindContext(
                    "IndicarDocReferencia(...)", this._selectedContext
                );
                oActionBinding.setParameter("OrdenCompra",          oData.OrdenCompra);
                oActionBinding.setParameter("HojaEntradaServicio",  oData.HojaEntradaServicio);
                oActionBinding.setParameter("EntradaMercancia",     oData.EntradaMercancia);
                oActionBinding.setParameter("AnioEntradaMercancia", oData.AnioEntradaMercancia);
                oActionBinding.setParameter("FolioReferencia",      oData.FolioReferencia);
                await oActionBinding.execute();
                MessageToast.show(this._i18n("msgDocRefOk"));
                this._closeDocRefDialog();
                this._refreshTable();
            } catch (oErr) {
                MessageBox.error(this._getErrorText(oErr));
            } finally {
                this._setBusy(false);
            }
        },

        onCancelDocRef:    function () { this._closeDocRefDialog(); },
        onDocRefDialogClose: function () { this._initDocRefModel(); },

        // =====================================================================
        // ACCIÓN: Indicar Posiciones
        // Carga posiciones de la OC/EM desde el backend y abre el diálogo.
        // =====================================================================
        onIndicarPosiciones: async function () {
            if (!this._selectedContext) return;

            this._setBusy(true);
            try {
                const oData = this._selectedContext.getObject();
                // Cargar posiciones de la OC desde el modelo OData
                const aPosiciones = await this._loadPosiciones(
                    oData.OrdenCompra,
                    oData.EntradaMercancia
                );

                const oModel = this.getView().getModel("posicionesModel");
                oModel.setProperty("/posiciones",   aPosiciones);
                oModel.setProperty("/monedaOC",     oData.Moneda || "CLP");
                oModel.setProperty("/totalFacturar", 0);

                this._openPosicionesDialog();
            } catch (oErr) {
                MessageBox.error(this._getErrorText(oErr));
            } finally {
                this._setBusy(false);
            }
        },

        onCantidadChange: function () {
            // Recalcular total cada vez que el usuario cambia una cantidad
            const aPosiciones = this.getView().getModel("posicionesModel")
                                              .getProperty("/posiciones");
            const fTotal = aPosiciones.reduce(
                (acc, p) => acc + (parseFloat(p.CantidadFacturar) || 0) * (parseFloat(p.PrecioUnit) || 0),
                0
            );
            this.getView().getModel("posicionesModel")
                          .setProperty("/totalFacturar", fTotal.toFixed(2));
        },

        onConfirmPosiciones: async function () {
            const aPosiciones = this.getView().getModel("posicionesModel")
                                              .getProperty("/posiciones")
                                              .filter(p => parseFloat(p.CantidadFacturar) > 0);

            if (!aPosiciones.length) {
                MessageBox.warning(this._i18n("msgNoPosicionesSeleccionadas"));
                return;
            }

            // Por limitación del BAPI (acción recibe una posición a la vez),
            // enviamos la primera posición con cantidad confirmada.
            // Para múltiples posiciones se puede extender con acciones adicionales.
            const oPosicion = aPosiciones[0];
            this._setBusy(true);
            try {
                const oActionBinding = this._selectedContext.getModel().bindContext(
                    "IndicarPosiciones(...)", this._selectedContext
                );
                oActionBinding.setParameter("Posicion",         oPosicion.Posicion);
                oActionBinding.setParameter("Material",         oPosicion.Material);
                oActionBinding.setParameter("CantidadOc",       oPosicion.CantidadOc);
                oActionBinding.setParameter("CantidadRecibida", oPosicion.CantidadRecibida);
                oActionBinding.setParameter("CantidadFacturar", oPosicion.CantidadFacturar);
                oActionBinding.setParameter("UnidadMedida",     oPosicion.UnidadMedida);
                oActionBinding.setParameter("MontoPos",         oPosicion.MontoPos);
                oActionBinding.setParameter("Moneda",           oPosicion.Moneda);
                await oActionBinding.execute();
                MessageToast.show(this._i18n("msgPosicionesOk"));
                this._closePosicionesDialog();
                this._refreshTable();
            } catch (oErr) {
                MessageBox.error(this._getErrorText(oErr));
            } finally {
                this._setBusy(false);
            }
        },

        onCancelPosiciones:  function () { this._closePosicionesDialog(); },
        onPosDialogClose:    function () { this._initPosicionesModel(); },

        // =====================================================================
        // ACCIÓN: Ver PDF
        // Genera un PDF en el navegador a partir del XML almacenado en el registro.
        // =====================================================================
        onVerPdf: async function () {
            if (!this._selectedContext) return;

            this._setBusy(true);
            try {
                const oData    = this._selectedContext.getObject();
                const sXmlData = oData.XmlData;

                if (!sXmlData) {
                    MessageBox.warning(this._i18n("msgSinXml"));
                    return;
                }

                // Generar HTML desde el XML del DTE y abrir en nueva pestaña
                const sHtml    = this._xmlDteToHtml(sXmlData, oData);
                const oBlob    = new Blob([sHtml], { type: "text/html;charset=utf-8" });
                const sUrl     = URL.createObjectURL(oBlob);
                window.open(sUrl, "_blank");
                // Liberar URL después de un tiempo
                setTimeout(() => URL.revokeObjectURL(sUrl), 60000);

            } catch (oErr) {
                MessageBox.error(this._getErrorText(oErr));
            } finally {
                this._setBusy(false);
            }
        },

        // =====================================================================
        // EXPORT A EXCEL
        // SmartTable con enableExport="true" lo maneja automáticamente.
        // Este método se puede usar para exportación personalizada.
        // =====================================================================
        onExportToExcel: function () {
            const oTable   = this.byId("monitorTable").getTable();
            const oBinding = oTable.getBinding("rows");

            const aColumns = [
                { label: "Tipo DTE",          property: "TipoDte",          type: EdmType.String },
                { label: "Folio",             property: "Folio",            type: EdmType.String },
                { label: "RUT Proveedor",     property: "Proveedor",        type: EdmType.String },
                { label: "Nombre Proveedor",  property: "NombreProveedor",  type: EdmType.String },
                { label: "Sociedad",          property: "Sociedad",         type: EdmType.String },
                { label: "Estado",            property: "Estado",           type: EdmType.String },
                { label: "Fecha Documento",   property: "FechaDocumento",   type: EdmType.Date },
                { label: "Fecha Recep. SII",  property: "FechaRecepcionSii",type: EdmType.Date },
                { label: "Monto Neto",        property: "MontoNeto",        type: EdmType.Number, scale: 2 },
                { label: "IVA Recuperable",   property: "IvaRecuperable",   type: EdmType.Number, scale: 2 },
                { label: "Total DTE",         property: "TotalDocumento",   type: EdmType.Number, scale: 2 },
                { label: "Moneda",            property: "Moneda",           type: EdmType.String },
                { label: "OC",               property: "OrdenCompra",      type: EdmType.String },
                { label: "HES",              property: "HojaEntradaServicio", type: EdmType.String },
                { label: "EM",               property: "EntradaMercancia",  type: EdmType.String },
                { label: "Doc. Factura SAP", property: "DocumentoFacturaSap", type: EdmType.String },
                { label: "Días Pendientes",  property: "DiasPendientes",   type: EdmType.Number, scale: 0 },
                { label: "Log",             property: "LogProcesamiento",  type: EdmType.String }
            ];

            const oSettings = {
                workbook: {
                    columns: aColumns,
                    hierarchyLevel: "Level"
                },
                dataSource: oBinding,
                fileName: `Monitor_DTE_${new Date().toISOString().slice(0,10)}.xlsx`,
                worker: false
            };

            const oSpreadsheet = new Spreadsheet(oSettings);
            oSpreadsheet.build().finally(() => oSpreadsheet.destroy());
        },

        // =====================================================================
        // HELPERS PRIVADOS
        // =====================================================================

        _initDocRefModel: function () {
            const oModel = new JSONModel({
                OrdenCompra:          "",
                HojaEntradaServicio:  "",
                EntradaMercancia:     "",
                AnioEntradaMercancia: "",
                FolioReferencia:      "",
                isValid:              false
            });
            this.getView().setModel(oModel, "docRefModel");
        },

        _initPosicionesModel: function () {
            const oModel = new JSONModel({
                posiciones:    [],
                monedaOC:      "CLP",
                totalFacturar: "0.00"
            });
            this.getView().setModel(oModel, "posicionesModel");
        },

        _resetButtons: function () {
            ["btnReprocesar","btnRechazar","btnVerPdf","btnDocRef","btnPosiciones"]
                .forEach(id => this.byId(id).setEnabled(false));
        },

        _setBusy: function (bBusy) {
            this.getView().setBusy(bBusy);
        },

        _refreshTable: function () {
            this._resetButtons();
            this._selectedContexts = [];
            this._selectedContext  = null;
            this.byId("monitorTable").rebindTable(true);
        },

        _openDocRefDialog: function () {
            if (!this._oDocRefDialog) {
                this._oDocRefDialog = this.loadFragment({
                    name: "com.fenixgold.dte.monitordte.view.DocRef"
                });
            }
            this._oDocRefDialog.then(dlg => dlg.open());
        },

        _closeDocRefDialog: function () {
            if (this._oDocRefDialog) {
                this._oDocRefDialog.then(dlg => dlg.close());
            }
        },

        _openPosicionesDialog: function () {
            if (!this._oPosDialog) {
                this._oPosDialog = this.loadFragment({
                    name: "com.fenixgold.dte.monitordte.view.Posiciones"
                });
            }
            this._oPosDialog.then(dlg => dlg.open());
        },

        _closePosicionesDialog: function () {
            if (this._oPosDialog) {
                this._oPosDialog.then(dlg => dlg.close());
            }
        },

        /** Carga posiciones de la OC/EM desde el backend via OData */
        _loadPosiciones: async function (sOC, sEM) {
            const oModel = this.getView().getModel();

            // Leer posiciones de la OC desde EKPO via OData estándar
            // (se asume que el service binding expone una entidad de PO items
            //  o se usa un FM custom. Aquí simulamos con datos de la OC)
            let aPosiciones = [];

            if (sOC) {
                // En implementación real: leer vía OData estándar de S/4HANA
                // o añadir una entidad custom al service binding
                // Placeholder: devolver estructura vacía para completar en Sprint 4
                aPosiciones = [
                    {
                        Posicion:         "00010",
                        Material:         "",
                        Descripcion:      "Posición OC " + sOC,
                        CantidadOc:       0,
                        CantidadRecibida: 0,
                        CantidadFacturar: 0,
                        UnidadMedida:     "UN",
                        PrecioUnit:       0,
                        MontoPos:         0,
                        Moneda:           "CLP"
                    }
                ];
            }

            return aPosiciones;
        },

        /** Pide el motivo de rechazo en un diálogo simple */
        _promptMotivo: function () {
            return new Promise(resolve => {
                const oDialog = new sap.m.Dialog({
                    title: this._i18n("dialogMotivoTitle"),
                    content: [
                        new sap.m.TextArea("motivoInput", {
                            placeholder: this._i18n("placeholderMotivo"),
                            rows: 3,
                            width: "100%"
                        })
                    ],
                    beginButton: new sap.m.Button({
                        type: "Reject",
                        text: this._i18n("btnRechazar"),
                        press: () => {
                            const sMotivo = sap.ui.getCore().byId("motivoInput").getValue();
                            oDialog.close();
                            oDialog.destroy();
                            resolve(sMotivo || this._i18n("defaultMotivo"));
                        }
                    }),
                    endButton: new sap.m.Button({
                        text: this._i18n("btnCancelar"),
                        press: () => {
                            oDialog.close();
                            oDialog.destroy();
                            resolve(null);
                        }
                    })
                });
                oDialog.open();
            });
        },

        /** Genera HTML para visualizar el DTE como documento (para PDF) */
        _xmlDteToHtml: function (sXmlData, oData) {
            return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>DTE ${oData.TipoDte} Folio ${oData.Folio}</title>
<style>
  body { font-family: Arial, sans-serif; font-size: 12px; margin: 20px; }
  h2   { text-align: center; }
  .header { display: flex; justify-content: space-between; margin-bottom: 16px; }
  table  { width: 100%; border-collapse: collapse; margin-top: 12px; }
  th, td { border: 1px solid #ccc; padding: 6px 8px; }
  th     { background: #f0f0f0; }
  .totales { margin-top: 12px; text-align: right; }
  .totales td { border: none; }
</style>
</head>
<body>
<h2>DOCUMENTO TRIBUTARIO ELECTRÓNICO</h2>
<div class="header">
  <div>
    <strong>Proveedor:</strong> ${oData.NombreProveedor || ""}<br>
    <strong>RUT:</strong> ${oData.Proveedor || ""}<br>
  </div>
  <div>
    <strong>Tipo DTE:</strong> ${oData.TipoDte || ""}<br>
    <strong>Folio:</strong> ${oData.Folio || ""}<br>
    <strong>Fecha:</strong> ${oData.FechaDocumento || ""}<br>
  </div>
</div>
<table>
  <thead>
    <tr>
      <th>Monto Neto</th><th>Monto Exento</th><th>IVA Recuperable</th>
      <th>IVA No Rec.</th><th>IVA Retenido</th><th>IEC</th><th>Total</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>${oData.MontoNeto || 0}</td>
      <td>${oData.MontoExento || 0}</td>
      <td>${oData.IvaRecuperable || 0}</td>
      <td>${oData.IvaNoRecuperable || 0}</td>
      <td>${oData.IvaRetenido || 0}</td>
      <td>${oData.Iec || 0}</td>
      <td><strong>${oData.TotalDocumento || 0}</strong></td>
    </tr>
  </tbody>
</table>
<div class="totales">
  <table><tr><td><strong>OC Referencia:</strong></td><td>${oData.OrdenCompra || "-"}</td></tr>
  <tr><td><strong>HES:</strong></td><td>${oData.HojaEntradaServicio || "-"}</td></tr>
  <tr><td><strong>EM:</strong></td><td>${oData.EntradaMercancia || "-"}</td></tr></table>
</div>
<hr/>
<pre style="font-size:9px;color:#888">${sXmlData.substring(0, 500)}...</pre>
</body></html>`;
        },

        _i18n: function (sKey) {
            return this.getView().getModel("i18n").getResourceBundle().getText(sKey);
        },

        _getErrorText: function (oErr) {
            if (oErr && oErr.error && oErr.error.message) return oErr.error.message;
            if (oErr && oErr.message) return oErr.message;
            return String(oErr);
        }

    });
});
