@EndUserText.label: 'VH Proveedor - Monitor DTE'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Search.searchable: true

define view entity ZVH_DTE_PROVEEDOR
  as select distinct from zdte_monitor
{
      @Search.defaultSearchElement: true
      @EndUserText.label: 'RUT Proveedor'
  key proveedor   as Proveedor,

      @EndUserText.label: 'Nombre Proveedor'
      nombre_prov  as NombreProveedor
}
