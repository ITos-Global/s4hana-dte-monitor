@EndUserText.label : 'Configuracion Monitor DTE'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zdte_config {

  key mandt     : mandt not null;
  "@<PARAMETRO> ejemplos: TOL_PORCENTAJE, TOL_MONTO_CLP, DIAS_RECHAZO"
  key parametro : abap.char( 30 ) not null;

  valor_num     : abap.dec( 15, 2 );
  valor_char    : abap.char( 50 );
  descripcion   : abap.char( 100 );

}
