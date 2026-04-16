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

  sociedad      : bukrs;
  prov_sap      : lifnr;
  nombre_prov   : abap.char( 80 );

  fe_fact       : abap.dats;
  fe_cont       : abap.dats;
  fe_recep      : abap.dats;
  fe_acept      : abap.dats;
  fe_venc       : abap.dats;

  estado        : abap.char( 2 );

  waers         : waers;

  @Semantics.amount.currencyCode : 'waers'
  monto_n       : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode : 'waers'
  monto_ex      : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode : 'waers'
  iec           : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode : 'waers'
  iva_rec       : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode : 'waers'
  iva_nrec      : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode : 'waers'
  iva_ret       : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode : 'waers'
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

  @Semantics.systemDate.createdAt : true
  erdat         : erdat;
  erzet         : erzet;
  @Semantics.user.createdBy : true
  ernam         : ernam;
  @Semantics.systemDate.lastChangedAt : true
  aedat         : aedat;
  @Semantics.user.lastChangedBy : true
  aenam         : aenam;

}
