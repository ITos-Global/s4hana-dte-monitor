@EndUserText.label : 'Historial / Tracking Monitor DTE'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zdte_monitor_h {

  key mandt     : mandt not null;
  key tipo_dte  : abap.numc( 3 ) not null;
  key folio     : abap.char( 20 ) not null;
  key proveedor : abap.char( 10 ) not null;
  key seqno     : abap.numc( 6 ) not null;

  timestamp     : tzntstmps;
  estado_ant    : abap.char( 2 );
  estado_nuevo  : abap.char( 2 );
  @Semantics.user.createdBy : true
  usrname       : uname;
  texto         : abap.string( 0 );

}
