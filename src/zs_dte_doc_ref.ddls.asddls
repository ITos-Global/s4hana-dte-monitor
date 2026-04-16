@EndUserText.label: 'Parametro Accion Indicar Documento Referencia'
define abstract entity ZS_DTE_DOC_REF {
  "@<OrdenCompra>         OC SAP (10 dígitos) — código 801 en sección <Referencia> del XML"
  OrdenCompra          : ebeln;

  "@<HojaEntradaServicio> Número HES SAP — servicio ya aceptado"
  HojaEntradaServicio  : belnr_d;

  "@<EntradaMercancia>    Número de entrada de mercancías SAP (MIGO)"
  EntradaMercancia     : belnr_d;

  "@<AnioEntradaMercancia> Año contable del documento EM"
  AnioEntradaMercancia : gjahr;

  "@<FolioReferencia>     Folio de la factura original (para NC / ND)"
  FolioReferencia      : abap.char( 20 );
}
