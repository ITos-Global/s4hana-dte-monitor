sap.ui.define([
    "sap/ui/core/mvc/Controller",
    "sap/ui/core/Fragment",
    "sap/ui/model/json/JSONModel",
    "sap/ui/model/Filter",
    "sap/ui/model/FilterOperator",
    "sap/m/MessageBox",
    "sap/m/MessageToast",
    "sap/m/SelectDialog",
    "sap/m/StandardListItem",
    "sap/ui/export/Spreadsheet",
    "sap/ui/export/library",
    "com/fenixgold/dte/monitordte/formatter/formatter"
], function (Controller, Fragment, JSONModel, Filter, FilterOperator, MessageBox, MessageToast, SelectDialog, StandardListItem, Spreadsheet, exportLibrary, formatter) {
    "use strict";

    const EdmType = exportLibrary.EdmType;
    const NS = "com.sap.gateway.srvd.zui_dte_monitor.v0001.";

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
            this._initMontosPendModel();
            this._selectedContext = null;
            this._selectedContexts = [];
            this._motivoResolver = null;
        },

        // =====================================================================
        // FILTER BAR — search & clear
        // =====================================================================
        onSearch: function () {
            const oBinding = this.byId("monitorTable").getBinding("rows");
            if (!oBinding) return;

            const aFilters = [];

            const sSociedad  = this.byId("filterSociedad").getValue();
            const sTipoDte   = this.byId("filterTipoDte").getSelectedKey();
            const sProveedor = this.byId("filterProveedor").getValue();
            const sEstado    = this.byId("filterEstado").getSelectedKey();
            const oFechaDoc  = this.byId("filterFechaDoc");
            const oFechaRec  = this.byId("filterFechaRecep");

            if (sSociedad)  aFilters.push(new Filter("Sociedad",  FilterOperator.EQ,       sSociedad));
            if (sTipoDte)   aFilters.push(new Filter("TipoDte",   FilterOperator.EQ,       sTipoDte));
            if (sProveedor) aFilters.push(new Filter("Proveedor", FilterOperator.Contains, sProveedor));
            if (sEstado)    aFilters.push(new Filter("Estado",    FilterOperator.EQ,       sEstado));

            if (oFechaDoc.getDateValue() && oFechaDoc.getSecondDateValue()) {
                aFilters.push(new Filter("FechaDocumento", FilterOperator.BT,
                    oFechaDoc.getDateValue(), oFechaDoc.getSecondDateValue()));
            }
            if (oFechaRec.getDateValue() && oFechaRec.getSecondDateValue()) {
                aFilters.push(new Filter("FechaRecepcionSii", FilterOperator.BT,
                    oFechaRec.getDateValue(), oFechaRec.getSecondDateValue()));
            }

            oBinding.filter(aFilters.length ? new Filter({ filters: aFilters, and: true }) : []);
        },

        onClearFilters: function () {
            this.byId("filterSociedad").setValue("");
            this.byId("filterTipoDte").setSelectedKey("");
            this.byId("filterProveedor").setValue("");
            this.byId("filterEstado").setSelectedKey("");
            this.byId("filterFechaDoc").setValue("");
            this.byId("filterFechaRecep").setValue("");
            const oBinding = this.byId("monitorTable").getBinding("rows");
            if (oBinding) oBinding.filter([]);
        },

        onRefresh: function () {
            this._refreshTable();
            MessageToast.show(this._i18n("msgRefrescado"));
        },

        // =====================================================================
        // LOG DE PROCESAMIENTO — abre diálogo con el log al click en estado
        // =====================================================================
        onMostrarLog: function (oEvent) {
            const oCtx = oEvent.getSource().getBindingContext();
            const sLog = oCtx.getProperty("LogProcesamiento") || "(sin log)";
            const sFolio = oCtx.getProperty("Folio");
            MessageBox.information(sLog, {
                title: "Log Procesamiento — Folio " + sFolio,
                contentWidth: "40rem"
            });
        },

        // =====================================================================
        // VALUE HELPS — SelectDialog vinculado a VH entities del servicio V4
        // =====================================================================
        onValueHelpSociedad: function () {
            this._openVhDialog({
                entitySet:    "VhSociedad",
                titleKey:     "filterSociedad",
                keyField:     "Sociedad",
                titleField:   "BukrsSap",      // CompanyCode SAP en título
                descField:    "Nombre",        // Nombre en descripción
                infoField:    "Sociedad",      // RUT en info
                targetInput:  "filterSociedad",
                searchField:  "Nombre"         // búsqueda principal por nombre
            });
        },

        onValueHelpProveedor: function () {
            this._openVhDialog({
                entitySet:   "VhProveedor",
                titleKey:    "filterProveedor",
                keyField:    "Proveedor",
                titleField:  "NombreProveedor",
                descField:   "Proveedor",
                targetInput: "filterProveedor",
                searchField: "NombreProveedor"
            });
        },

        _openVhDialog: function (oConfig) {
            const oDialog = new SelectDialog({
                title: this._i18n(oConfig.titleKey),
                multiSelect: false,
                growing: true,
                growingThreshold: 50,
                items: {
                    path: "/" + oConfig.entitySet,
                    template: new StandardListItem({
                        title:       "{" + oConfig.titleField + "}",
                        description: oConfig.descField ? "{" + oConfig.descField + "}" : undefined,
                        info:        oConfig.infoField ? "{" + oConfig.infoField + "}" : undefined
                    })
                },
                confirm: (oEvent) => {
                    const oSelected = oEvent.getParameter("selectedItem");
                    if (oSelected) {
                        const oCtx = oSelected.getBindingContext();
                        this.byId(oConfig.targetInput).setValue(
                            oCtx.getProperty(oConfig.keyField)
                        );
                    }
                    oDialog.destroy();
                },
                cancel: () => oDialog.destroy(),
                liveChange: (oEvent) => {
                    const oBinding = oEvent.getSource().getBinding("items");
                    if (!oBinding) { return; }
                    const sValue = oEvent.getParameter("value");
                    const oFilter = sValue
                        ? new Filter(oConfig.searchField, FilterOperator.Contains, sValue)
                        : null;
                    oBinding.filter(oFilter ? [oFilter] : []);
                },
                search: (oEvent) => {
                    const oBinding = oEvent.getSource().getBinding("items");
                    if (!oBinding) { return; }
                    const sValue = oEvent.getParameter("value");
                    const oFilter = sValue
                        ? new Filter(oConfig.searchField, FilterOperator.Contains, sValue)
                        : null;
                    oBinding.filter(oFilter ? [oFilter] : []);
                }
            });

            this.getView().addDependent(oDialog);
            oDialog.open();
        },

        // =====================================================================
        // SELECCIÓN DE FILAS — habilita/deshabilita botones dinámicamente
        // =====================================================================
        onRowSelectionChange: function () {
            const oInnerTable = this.byId("monitorTable");
            const aIndices    = oInnerTable.getSelectedIndices();
            const oBinding    = oInnerTable.getBinding("rows");

            if (!oBinding || aIndices.length === 0) {
                this._resetButtons();
                this._selectedContexts = [];
                this._selectedContext  = null;
                return;
            }

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

            // Montos pendientes: requiere selección única con OC + HES indicados.
            const oCtx = this._selectedContext;
            const bConHes = bSingle && !!oCtx
                && !!oCtx.getProperty("OrdenCompra")
                && !!oCtx.getProperty("HojaEntradaServicio");
            this.byId("btnMontosPend").setEnabled(bConHes);
        },

        // =====================================================================
        // ACCIÓN: Reprocesar
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
                                        NS + "Reprocesar(...)",
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

                    const sMotivo = await this._promptMotivo();
                    if (sMotivo === null) return;

                    this._setBusy(true);
                    try {
                        await Promise.all(
                            aCtxs.map(ctx => {
                                const oActionBinding = ctx.getModel().bindContext(
                                    NS + "Rechazar(...)", ctx
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
        // =====================================================================
        onIndicarDocRef: function () {
            if (!this._selectedContext) return;

            const oData = this._selectedContext.getObject();
            this.getView().getModel("docRefModel").setData({
                OrdenCompra:          oData.OrdenCompra          || "",
                HojaEntradaServicio:  oData.HojaEntradaServicio  || "",
                EntradaMercancia:     oData.EntradaMercancia     || "",
                AnioEntradaMercancia: oData.AnioEntradaMercancia || "",
                FolioReferencia:      oData.FolioReferencia      || "",
                isValid:              false
            });

            this._openDocRefDialog();
        },

        onDocRefFieldChange: function () {
            const oModel = this.getView().getModel("docRefModel");
            const oData  = oModel.getData();
            const bValid = !!(oData.OrdenCompra || oData.HojaEntradaServicio ||
                              oData.EntradaMercancia || oData.FolioReferencia);
            oModel.setProperty("/isValid", bValid);
        },

        onConfirmDocRef: async function () {
            const oData = this.getView().getModel("docRefModel").getData();
            this._setBusy(true);
            try {
                const oActionBinding = this._selectedContext.getModel().bindContext(
                    NS + "IndicarDocReferencia(...)", this._selectedContext
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

        onCancelDocRef:      function () { this._closeDocRefDialog(); },
        onDocRefDialogClose: function () { this._initDocRefModel(); },

        // =====================================================================
        // ACCIÓN: Indicar Posiciones
        // =====================================================================
        onIndicarPosiciones: async function () {
            if (!this._selectedContext) return;

            this._setBusy(true);
            try {
                const oData = this._selectedContext.getObject();
                const aPosiciones = await this._loadPosiciones(
                    oData.OrdenCompra,
                    oData.EntradaMercancia
                );

                const oModel = this.getView().getModel("posicionesModel");
                oModel.setProperty("/posiciones",    aPosiciones);
                oModel.setProperty("/monedaOC",      oData.Moneda || "CLP");
                oModel.setProperty("/totalFacturar", 0);

                this._openPosicionesDialog();
            } catch (oErr) {
                MessageBox.error(this._getErrorText(oErr));
            } finally {
                this._setBusy(false);
            }
        },

        onCantidadChange: function () {
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

            const oPosicion = aPosiciones[0];
            this._setBusy(true);
            try {
                const oActionBinding = this._selectedContext.getModel().bindContext(
                    NS + "IndicarPosiciones(...)", this._selectedContext
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
        // ACCIÓN: Ver Montos Pendientes (function bound GetMontosPendientes)
        // =====================================================================
        onVerMontosPendientes: async function () {
            if (!this._selectedContext) return;

            this._setBusy(true);
            try {
                const oCtx   = this._selectedContext;
                const oData  = oCtx.getObject();

                const oOp = oCtx.getModel().bindContext(
                    NS + "GetMontosPendientes(...)", oCtx
                );
                await oOp.execute();

                // El resultado de una function que devuelve [0..*] viene como
                // colección bajo .value en V4.
                const oRes = await oOp.getBoundContext().requestObject();
                const aRows = (oRes && Array.isArray(oRes.value)) ? oRes.value
                            : Array.isArray(oRes) ? oRes : [];

                const fTotal = aRows.reduce(
                    (acc, r) => acc + (parseFloat(r.PurchaseOrderAmount) || 0),
                    0
                );
                const sMonedaTotal = aRows.length ? aRows[0].DocumentCurrency : (oData.Moneda || "");

                const oModel = this.getView().getModel("montosPendModel");
                oModel.setProperty("/posiciones",          aRows);
                oModel.setProperty("/ordenCompra",         oData.OrdenCompra || "");
                oModel.setProperty("/hojaEntradaServicio", oData.HojaEntradaServicio || "");
                oModel.setProperty("/totalDte",            oData.TotalDocumento || 0);
                oModel.setProperty("/monedaDte",           oData.Moneda || "");
                oModel.setProperty("/totalPendiente",      fTotal.toFixed(2));
                oModel.setProperty("/monedaTotal",         sMonedaTotal);

                if (!aRows.length) {
                    MessageToast.show(this._i18n("msgSinMontosPend"));
                }

                this._openMontosPendDialog();
            } catch (oErr) {
                MessageBox.error(this._getErrorText(oErr));
            } finally {
                this._setBusy(false);
            }
        },

        onCloseMontosPend:        function () { this._closeMontosPendDialog(); },
        onMontosPendDialogClose:  function () { this._initMontosPendModel(); },

        // =====================================================================
        // ACCIÓN: Ver PDF
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

                const sHtml = this._xmlDteToHtml(sXmlData, oData);
                const oBlob = new Blob([sHtml], { type: "text/html;charset=utf-8" });
                const sUrl  = URL.createObjectURL(oBlob);
                window.open(sUrl, "_blank");
                setTimeout(() => URL.revokeObjectURL(sUrl), 60000);

            } catch (oErr) {
                MessageBox.error(this._getErrorText(oErr));
            } finally {
                this._setBusy(false);
            }
        },

        // =====================================================================
        // EXPORT A EXCEL
        // =====================================================================
        onExportToExcel: function () {
            const oTable   = this.byId("monitorTable");
            const oBinding = oTable.getBinding("rows");

            const aColumns = [
                { label: "Tipo DTE",          property: "TipoDte",             type: EdmType.String },
                { label: "Folio",             property: "Folio",               type: EdmType.String },
                { label: "RUT Proveedor",     property: "Proveedor",           type: EdmType.String },
                { label: "Nombre Proveedor",  property: "NombreProveedor",     type: EdmType.String },
                { label: "Sociedad",          property: "Sociedad",            type: EdmType.String },
                { label: "Estado",            property: "Estado",              type: EdmType.String },
                { label: "Fecha Documento",   property: "FechaDocumento",      type: EdmType.Date },
                { label: "Fecha Recep. SII",  property: "FechaRecepcionSii",   type: EdmType.Date },
                { label: "Monto Neto",        property: "MontoNeto",           type: EdmType.Number, scale: 2 },
                { label: "IVA Recuperable",   property: "IvaRecuperable",      type: EdmType.Number, scale: 2 },
                { label: "Total DTE",         property: "TotalDocumento",      type: EdmType.Number, scale: 2 },
                { label: "Moneda",            property: "Moneda",              type: EdmType.String },
                { label: "OC",                property: "OrdenCompra",         type: EdmType.String },
                { label: "HES",               property: "HojaEntradaServicio", type: EdmType.String },
                { label: "EM",                property: "EntradaMercancia",    type: EdmType.String },
                { label: "Doc. Factura SAP",  property: "DocumentoFacturaSap", type: EdmType.String },
                { label: "Días Pendientes",   property: "DiasPendientes",      type: EdmType.Number, scale: 0 },
                { label: "Log",               property: "LogProcesamiento",    type: EdmType.String }
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
        // DIALOGO MOTIVO DE RECHAZO (fragment)
        // =====================================================================
        onMotivoConfirm: function () {
            const oInput = Fragment.byId(this.getView().getId(), "motivoInput");
            const sMotivo = oInput.getValue();
            this._closeMotivoDialog();
            if (this._motivoResolver) {
                this._motivoResolver(sMotivo || this._i18n("defaultMotivo"));
                this._motivoResolver = null;
            }
        },

        onMotivoCancel: function () {
            this._closeMotivoDialog();
            if (this._motivoResolver) {
                this._motivoResolver(null);
                this._motivoResolver = null;
            }
        },

        _promptMotivo: function () {
            return new Promise(resolve => {
                this._motivoResolver = resolve;
                if (!this._pMotivoDialog) {
                    this._pMotivoDialog = Fragment.load({
                        id: this.getView().getId(),
                        name: "com.fenixgold.dte.monitordte.view.MotivoRechazo",
                        controller: this
                    }).then(oDialog => {
                        this.getView().addDependent(oDialog);
                        return oDialog;
                    });
                }
                this._pMotivoDialog.then(oDialog => {
                    Fragment.byId(this.getView().getId(), "motivoInput").setValue("");
                    oDialog.open();
                });
            });
        },

        _closeMotivoDialog: function () {
            if (this._pMotivoDialog) {
                this._pMotivoDialog.then(oDialog => oDialog.close());
            }
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

        _initMontosPendModel: function () {
            const oModel = new JSONModel({
                posiciones:          [],
                ordenCompra:         "",
                hojaEntradaServicio: "",
                totalDte:            0,
                monedaDte:           "",
                totalPendiente:      "0.00",
                monedaTotal:         ""
            });
            this.getView().setModel(oModel, "montosPendModel");
        },

        _resetButtons: function () {
            ["btnReprocesar","btnRechazar","btnVerPdf","btnDocRef","btnPosiciones","btnMontosPend"]
                .forEach(id => this.byId(id).setEnabled(false));
        },

        _setBusy: function (bBusy) {
            this.getView().setBusy(bBusy);
        },

        _refreshTable: function () {
            this._resetButtons();
            this._selectedContexts = [];
            this._selectedContext  = null;
            const oBinding = this.byId("monitorTable").getBinding("rows");
            if (oBinding) oBinding.refresh();
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

        _openMontosPendDialog: function () {
            if (!this._oMontosPendDialog) {
                this._oMontosPendDialog = this.loadFragment({
                    name: "com.fenixgold.dte.monitordte.view.MontosPendientes"
                });
            }
            this._oMontosPendDialog.then(dlg => dlg.open());
        },

        _closeMontosPendDialog: function () {
            if (this._oMontosPendDialog) {
                this._oMontosPendDialog.then(dlg => dlg.close());
            }
        },

        /** Carga posiciones de la OC/EM desde el backend via OData */
        _loadPosiciones: async function (sOC, sEM) {
            let aPosiciones = [];

            if (sOC) {
                // Placeholder: a completar en Sprint 4 con entidad custom o OData estándar
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
