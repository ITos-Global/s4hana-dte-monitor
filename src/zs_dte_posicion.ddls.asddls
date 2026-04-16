@EndUserText.label: 'Parametro Accion Indicar Posiciones DTE'
define abstract entity ZS_DTE_POSICION {
  "@<Posicion>         Número de posición de la OC (EKPO-EBELP)"
  Posicion         : abap.numc( 5 );

  "@<Material>         Material SAP de la posición"
  Material         : matnr;

  "@<CantidadOc>       Cantidad original en la OC"
  CantidadOc       : menge_d;

  "@<CantidadRecibida> Cantidad ya recibida acumulada (EM anteriores)"
  CantidadRecibida : menge_d;

  "@<CantidadFacturar> Cantidad que el usuario confirma para este DTE"
  CantidadFacturar : menge_d;

  "@<UnidadMedida>     Unidad de medida de la posición"
  UnidadMedida     : meins;

  "@<MontoPos>         Monto de la posición para este DTE (en moneda OC)"
  MontoPos         : abap.curr( 15, 2 );

  "@<Moneda>           Moneda de la OC"
  Moneda           : waers;
}
