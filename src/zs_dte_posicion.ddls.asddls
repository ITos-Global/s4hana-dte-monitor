@EndUserText.label: 'Parametro Accion Indicar Posiciones DTE'
define abstract entity ZS_DTE_POSICION {
  Posicion         : abap.numc( 5 );
  Material         : matnr;
  CantidadOc       : abap.dec( 13, 3 );
  CantidadRecibida : abap.dec( 13, 3 );
  CantidadFacturar : abap.dec( 13, 3 );
  UnidadMedida     : meins;
  @Semantics.amount.currencyCode: 'Moneda'
  MontoPos         : abap.curr( 15, 2 );
  @Semantics.currencyCode: true
  Moneda           : abap.cuky;
}
