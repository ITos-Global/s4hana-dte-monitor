@EndUserText.label: 'Parametro Accion Indicar Documento Referencia'
define abstract entity ZS_DTE_DOC_REF {
  OrdenCompra          : ebeln;
  HojaEntradaServicio  : belnr_d;
  EntradaMercancia     : belnr_d;
  AnioEntradaMercancia : gjahr;
  FolioReferencia      : abap.char( 20 );
}
