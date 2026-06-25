@EndUserText.label: 'Posicion OC-EM con saldo pendiente'
define abstract entity ZS_DTE_POS_EM {
  Posicion         : abap.numc( 5 );
  Material         : matnr;
  Descripcion      : abap.char( 40 );
  CantidadOc       : abap.dec( 13, 3 );
  CantidadRecibida : abap.dec( 13, 3 );
  CantidadFacturar : abap.dec( 13, 3 );
  UnidadMedida     : meins;
  @Semantics.amount.currencyCode: 'Moneda'
  PrecioUnit       : abap.curr( 15, 2 );
  @Semantics.amount.currencyCode: 'Moneda'
  MontoPos         : abap.curr( 15, 2 );
  @Semantics.currencyCode: true
  Moneda           : abap.cuky;
}
