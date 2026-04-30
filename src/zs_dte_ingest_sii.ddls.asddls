@EndUserText.label: 'Parametro Accion Ingest from SII'
define abstract entity ZS_DTE_INGEST_SII {
  TipoDte           : abap.numc( 3 );
  Folio             : abap.char( 20 );
  Proveedor         : abap.char( 10 );  // RUT proveedor
  Sociedad          : abap.char( 10 );  // RUT receptor
  FechaRecepcionSii : abap.dats;
  FechaDocumento    : abap.dats;
  Moneda            : waers;
  @Semantics.amount.currencyCode: 'Moneda'
  MontoTotal        : abap.curr( 15, 2 );
}
