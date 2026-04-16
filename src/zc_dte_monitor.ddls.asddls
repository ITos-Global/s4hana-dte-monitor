@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Monitor DTE Proveedor - Projection View'
@Metadata.allowExtensions: true

@UI.headerInfo: {
  typeName: 'DTE Proveedor',
  typeNamePlural: 'DTE Proveedores',
  title: { type: #STANDARD, value: 'Folio' },
  description: { type: #STANDARD, value: 'NombreProveedor' }
}

define root view entity ZC_DTE_MONITOR
  provider contract transactional_query
  as projection on ZI_DTE_MONITOR
{
      @UI.lineItem:       [{ position: 10, label: 'Tipo DTE' }]
      @UI.selectionField: [{ position: 10 }]
      @UI.fieldGroup:     [{ qualifier: 'GeneralData', position: 10 }]
  key TipoDte,

      @UI.lineItem:       [{ position: 20, label: 'Folio' }]
      @UI.fieldGroup:     [{ qualifier: 'GeneralData', position: 20 }]
  key Folio,

      @UI.lineItem:       [{ position: 30, label: 'RUT Proveedor' }]
      @UI.selectionField: [{ position: 20 }]
      @UI.fieldGroup:     [{ qualifier: 'GeneralData', position: 30 }]
  key Proveedor,

      @UI.lineItem:       [{ position: 40, label: 'Sociedad' }]
      @UI.selectionField: [{ position: 30 }]
      @UI.fieldGroup:     [{ qualifier: 'GeneralData', position: 40 }]
      Sociedad,

      @UI.fieldGroup:     [{ qualifier: 'GeneralData', position: 50 }]
      ProveedorSap,

      @UI.lineItem:       [{ position: 50, label: 'Proveedor' }]
      @UI.fieldGroup:     [{ qualifier: 'GeneralData', position: 60 }]
      NombreProveedor,

      @UI.lineItem: [{
        position:    60,
        label:       'Estado',
        criticality: 'Criticality',
        criticalityRepresentation: #WITH_ICON
      }]
      @UI.selectionField: [{ position: 40 }]
      @UI.fieldGroup:     [{ qualifier: 'GeneralData', position: 70 }]
      Estado,

      Criticality,

      @UI.lineItem:       [{ position: 70, label: 'Fecha Documento' }]
      @UI.selectionField: [{ position: 50 }]
      @UI.fieldGroup:     [{ qualifier: 'FechasFacet', position: 10 }]
      FechaDocumento,

      @UI.fieldGroup:     [{ qualifier: 'FechasFacet', position: 20 }]
      FechaContabilizacion,

      @UI.lineItem:       [{ position: 80, label: 'Recepcion SII' }]
      @UI.selectionField: [{ position: 60 }]
      @UI.fieldGroup:     [{ qualifier: 'FechasFacet', position: 30 }]
      FechaRecepcionSii,

      @UI.fieldGroup:     [{ qualifier: 'FechasFacet', position: 40 }]
      FechaAceptacion,

      @UI.lineItem:       [{ position: 90, label: 'Fecha Venc.' }]
      @UI.fieldGroup:     [{ qualifier: 'FechasFacet', position: 50 }]
      FechaVencimiento,

      @UI.lineItem:       [{ position: 100, label: 'Dias Pend.' }]
      @UI.fieldGroup:     [{ qualifier: 'GeneralData', position: 80 }]
      DiasPendientes,

      Moneda,

      @UI.lineItem:   [{ position: 110, label: 'Monto Neto' }]
      @UI.fieldGroup: [{ qualifier: 'MontosFacet', position: 10 }]
      MontoNeto,

      @UI.fieldGroup: [{ qualifier: 'MontosFacet', position: 20 }]
      MontoExento,

      @UI.fieldGroup: [{ qualifier: 'MontosFacet', position: 30 }]
      Iec,

      @UI.fieldGroup: [{ qualifier: 'MontosFacet', position: 40 }]
      IvaRecuperable,

      @UI.fieldGroup: [{ qualifier: 'MontosFacet', position: 50 }]
      IvaNoRecuperable,

      @UI.fieldGroup: [{ qualifier: 'MontosFacet', position: 60 }]
      IvaRetenido,

      @UI.lineItem:   [{ position: 120, label: 'Total DTE' }]
      @UI.fieldGroup: [{ qualifier: 'MontosFacet', position: 70 }]
      TotalDocumento,

      @UI.fieldGroup: [{ qualifier: 'DocSapFacet', position: 10 }]
      DocumentoFacturaSap,

      @UI.fieldGroup: [{ qualifier: 'DocSapFacet', position: 20 }]
      AnioFacturaSap,

      @UI.fieldGroup: [{ qualifier: 'DocSapFacet', position: 30 }]
      OrdenCompra,

      @UI.fieldGroup: [{ qualifier: 'DocSapFacet', position: 40 }]
      EntradaMercancia,

      @UI.fieldGroup: [{ qualifier: 'DocSapFacet', position: 50 }]
      AnioEntradaMercancia,

      @UI.fieldGroup: [{ qualifier: 'DocSapFacet', position: 60 }]
      HojaEntradaServicio,

      @UI.fieldGroup: [{ qualifier: 'DocSapFacet', position: 70 }]
      FolioReferencia,

      @UI.fieldGroup: [{ qualifier: 'LogFacet', position: 10 }]
      LogProcesamiento,

      XmlData,

      @UI.fieldGroup: [{ qualifier: 'AuditFacet', position: 10 }]
      FechaCreacion,
      HoraCreacion,
      @UI.fieldGroup: [{ qualifier: 'AuditFacet', position: 20 }]
      UsuarioCreacion,
      @UI.fieldGroup: [{ qualifier: 'AuditFacet', position: 30 }]
      FechaModificacion,
      @UI.fieldGroup: [{ qualifier: 'AuditFacet', position: 40 }]
      UsuarioModificacion,

      @UI.lineItem: [
        { type: #FOR_ACTION, dataAction: 'Reprocesar',           label: 'Reprocesar',       position: 10 },
        { type: #FOR_ACTION, dataAction: 'Rechazar',             label: 'Rechazar',          position: 20 },
        { type: #FOR_ACTION, dataAction: 'IndicarDocReferencia', label: 'Indicar Doc. Ref.', position: 30 },
        { type: #FOR_ACTION, dataAction: 'IndicarPosiciones',    label: 'Indicar Posiciones',position: 40 }
      ]

      _Historial: redirected to composition child ZC_DTE_MONITOR_H
}
