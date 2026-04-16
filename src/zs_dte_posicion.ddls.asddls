@EndUserText.label: 'Parametro Accion Indicar Posiciones DTE'
define abstract entity ZS_DTE_POSICION {
  Posicion         : abap.numc( 5 );
  Material         : matnr;
  CantidadOc       : menge_d;
  CantidadRecibida : menge_d;
  CantidadFacturar : menge_d;
  UnidadMedida     : meins;
  @Semantics.amount.currencyCode: 'Moneda'
  MontoPos         : abap.curr( 15, 2 );
  @Semantics.currencyCode: true
  Moneda           : abap.cuky;
}
