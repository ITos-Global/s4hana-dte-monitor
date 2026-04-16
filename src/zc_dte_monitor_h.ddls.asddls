@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Historial Monitor DTE - Projection View'
@Metadata.allowExtensions: true

define view entity ZC_DTE_MONITOR_H
  as projection on ZI_DTE_MONITOR_H
{
      @UI.lineItem: [{ position: 10, label: 'Seq.' }]
  key SeqNo,
  key TipoDte,
  key Folio,
  key Proveedor,

      @UI.lineItem: [{ position: 20, label: 'Fecha/Hora' }]
      Timestamp,

      @UI.lineItem: [{ position: 30, label: 'Estado Ant.' }]
      EstadoAnterior,

      @UI.lineItem: [{ position: 40, label: 'Estado Nuevo' }]
      EstadoNuevo,

      @UI.lineItem: [{ position: 50, label: 'Usuario' }]
      Usuario,

      @UI.lineItem: [{ position: 60, label: 'Descripción' }]
      Descripcion,

      _DteMonitor: redirected to parent ZC_DTE_MONITOR
}
