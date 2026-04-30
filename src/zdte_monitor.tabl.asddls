@EndUserText.label : 'Monitor DTE Proveedor'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zdte_monitor {

  key mandt     : mandt not null;
  key tipo_dte  : abap.numc( 3 ) not null;
  key folio     : abap.char( 20 ) not null;
  key proveedor : abap.char( 10 ) not null;

  sociedad      : abap.char( 10 );  " RUT receptor del DTE
  bukrs_sap     : bukrs;             " CompanyCode SAP resuelto en proceso
  prov_sap      : lifnr;
  nombre_prov   : abap.char( 80 );

  fe_fact       : abap.dats;
  fe_cont       : abap.dats;
  fe_recep      : abap.dats;
  fe_acept      : abap.dats;
  fe_venc       : abap.dats;

  estado        : abap.char( 2 );

  waers         : abap.cuky;

  @Semantics.amount.currencyCode : 'zdte_monitor.waers'
  monto_n       : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode : 'zdte_monitor.waers'
  monto_ex      : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode : 'zdte_monitor.waers'
  iec           : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode : 'zdte_monitor.waers'
  iva_rec       : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode : 'zdte_monitor.waers'
  iva_nrec      : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode : 'zdte_monitor.waers'
  iva_ret       : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode : 'zdte_monitor.waers'
  total_doc     : abap.curr( 15, 2 );

  doc_fact      : belnr_d;
  year_fact     : gjahr;

  oc            : ebeln;
  em            : belnr_d;
  year_em       : gjahr;
  hes           : belnr_d;

  folio_ref     : abap.char( 20 );

  @Semantics.largeObject.mimeType : 'text/xml'
  xml_data      : abap.string( 0 );

  log_proc      : abap.string( 0 );

  dias_pend     : abap.int4;

  erdat         : erdat;
  erzet         : abap.tims;
  ernam         : ernam;
  aedat         : aedat;
  aenam         : aenam;

}
