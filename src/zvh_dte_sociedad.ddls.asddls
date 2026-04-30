@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VH Sociedad - RUT receptor'
@Search.searchable: true
define view entity ZVH_DTE_SOCIEDAD
  as select from   I_AddlCompanyCodeInformation as a
    association [0..1] to I_CompanyCode as _CC on $projection.BukrsSap = _CC.CompanyCode
{
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold:   0.8
      @EndUserText.label: 'RUT Sociedad'
  key a.CompanyCodeParameterValue as Sociedad,
      @EndUserText.label: 'CompanyCode SAP'
      a.CompanyCode               as BukrsSap,
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Nombre Sociedad'
      _CC.CompanyCodeName         as Nombre
}
where
  a.CompanyCodeParameterType = 'TAXNR'
