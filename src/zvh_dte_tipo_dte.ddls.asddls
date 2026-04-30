@EndUserText.label: 'VH Tipo DTE - Monitor DTE'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Search.searchable: true
define view entity ZVH_DTE_TIPO_DTE
  as select distinct from zdte_monitor
{
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Tipo DTE'
  key tipo_dte as TipoDte,
      @EndUserText.label: 'Descripción'
      case tipo_dte
        when '033' then 'Factura Afecta'
        when '034' then 'Factura Exenta'
        when '046' then 'Factura de Compra'
        when '055' then 'Nota de Débito'
        when '056' then 'Nota de Crédito'
        else            tipo_dte
      end                as TipoDteText
}
