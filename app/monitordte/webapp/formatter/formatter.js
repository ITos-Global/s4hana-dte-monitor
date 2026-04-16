sap.ui.define([], function () {
    "use strict";

    // Mapa de estados del DTE
    const ESTADOS = {
        "01": "Pendiente",
        "02": "Aprobado",
        "03": "Rechazado",
        "04": "Por rechazar",
        "05": "No procesado",
        "06": "Contabilizado"
    };

    // Mapa de tipos DTE chilenos
    const TIPOS_DTE = {
        "033": "Factura Afecta",
        "034": "Factura Exenta",
        "046": "Factura de Compra",
        "055": "Nota de Débito",
        "056": "Nota de Crédito"
    };

    return {

        // =====================================================================
        // Estado → texto legible
        // =====================================================================
        estadoText: function (sEstado) {
            return ESTADOS[sEstado] || sEstado || "";
        },

        // =====================================================================
        // Tipo DTE → texto legible
        // =====================================================================
        tipoDteText: function (sTipo) {
            const sKey = String(sTipo).padStart(3, "0");
            return TIPOS_DTE[sKey] || `Tipo ${sTipo}`;
        },

        // =====================================================================
        // Criticality (valor numérico) → ValueState para ObjectStatus / MessageStrip
        // 0 = None, 1 = Error (rojo), 2 = Warning (amarillo), 3 = Success (verde)
        // =====================================================================
        criticalityToState: function (iCriticality) {
            switch (parseInt(iCriticality, 10)) {
                case 1:  return "Error";
                case 2:  return "Warning";
                case 3:  return "Success";
                default: return "None";
            }
        },

        // =====================================================================
        // Criticality → icono para ObjectStatus
        // =====================================================================
        criticalityToIcon: function (iCriticality) {
            switch (parseInt(iCriticality, 10)) {
                case 1:  return "sap-icon://error";
                case 2:  return "sap-icon://alert";
                case 3:  return "sap-icon://accept";
                default: return "";
            }
        },

        // =====================================================================
        // Días pendientes → texto con indicador visual
        // =====================================================================
        diasPendientesText: function (iDias) {
            if (iDias === null || iDias === undefined) return "";
            const n = parseInt(iDias, 10);
            if (n >= 7) return `${n} días ⚠ RECHAZO`;
            if (n >= 5) return `${n} días ⚠`;
            return String(n);
        },

        // =====================================================================
        // Formatear moneda CLP (sin decimales) u otras monedas (2 decimales)
        // =====================================================================
        formatCurrency: function (fMonto, sMoneda) {
            if (fMonto === null || fMonto === undefined) return "";
            const sMon = sMoneda || "CLP";
            const oFmt = sap.ui.core.format.NumberFormat.getCurrencyInstance({
                currencyCode: false,
                decimals: sMon === "CLP" ? 0 : 2,
                groupingEnabled: true
            });
            return `${oFmt.format(fMonto)} ${sMon}`;
        },

        // =====================================================================
        // Formatear fecha AAAA-MM-DD → DD/MM/AAAA
        // =====================================================================
        formatDate: function (sDate) {
            if (!sDate || sDate.length < 8) return sDate || "";
            // OData V4 devuelve fechas como "2026-04-15"
            if (sDate.includes("-")) {
                const [y, m, d] = sDate.split("-");
                return `${d}/${m}/${y}`;
            }
            // ABAP format AAAAMMDD
            return `${sDate.slice(6,8)}/${sDate.slice(4,6)}/${sDate.slice(0,4)}`;
        },

        // =====================================================================
        // Booleano visible: true si el estado es editable (04)
        // =====================================================================
        isEditable: function (sEstado) {
            return sEstado === "04";
        },

        // =====================================================================
        // Criticality días pendientes → state
        // =====================================================================
        criticalityDias: function (iDias) {
            const n = parseInt(iDias, 10);
            if (n >= 7) return "Error";
            if (n >= 5) return "Warning";
            return "None";
        }
    };
});
