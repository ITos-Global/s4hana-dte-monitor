@EndUserText.label: 'Parametro Accion Ingest from SII'
define abstract entity ZS_DTE_INGEST_SII {
  TipoDte           : abap.numc( 3 );
  Folio             : abap.char( 20 );
  Proveedor         : abap.char( 10 );
  Sociedad          : abap.char( 10 );
  NombreProveedor   : abap.char( 80 );
  FechaRecepcionSii : abap.dats;
  FechaDocumento    : abap.dats;
  Moneda            : waers;
  @Semantics.amount.currencyCode: 'Moneda'
  MontoNeto         : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode: 'Moneda'
  MontoExento       : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode: 'Moneda'
  IvaRecuperable    : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode: 'Moneda'
  IvaNoRecuperable  : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode: 'Moneda'
  IvaRetenido       : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode: 'Moneda'
  MontoTotal        : abap.curr( 15, 2 );
}
