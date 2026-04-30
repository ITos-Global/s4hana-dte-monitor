@EndUserText.label: 'VH Estado DTE - Monitor DTE'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Search.searchable: true

define view entity ZVH_DTE_ESTADO
  as select distinct from zdte_monitor
{
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Estado'
  key estado as Estado,

      @EndUserText.label: 'Descripción'
      case estado
        when '01' then 'Pendiente'
        when '02' then 'Aprobado'
        when '03' then 'Rechazado'
        when '04' then 'Por rechazar'
        when '05' then 'No procesado'
        when '06' then 'Contabilizado'
        else            estado
      end               as EstadoText
}
