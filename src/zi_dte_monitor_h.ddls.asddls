@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Historial Monitor DTE - Interface View'

define view entity ZI_DTE_MONITOR_H
  as select from zdte_monitor_h as h
  association to parent ZI_DTE_MONITOR as _DteMonitor
    on  $projection.TipoDte   = _DteMonitor.TipoDte
    and $projection.Folio     = _DteMonitor.Folio
    and $projection.Proveedor = _DteMonitor.Proveedor
{
  key h.tipo_dte                    as TipoDte,
  key h.folio                       as Folio,
  key h.proveedor                   as Proveedor,
  key h.seqno                       as SeqNo,

      h.timestamp                   as Timestamp,
      h.estado_ant                  as EstadoAnterior,
      h.estado_nuevo                as EstadoNuevo,
      h.usrname                     as Usuario,
      h.texto                       as Descripcion,

      _DteMonitor
}
