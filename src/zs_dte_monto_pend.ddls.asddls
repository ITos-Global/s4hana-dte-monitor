@EndUserText.label: 'Resultado Montos Pendientes por Posicion'
define abstract entity ZS_DTE_MONTO_PEND
{
  PurchaseOrder         : abap.char( 10 );
  PurchaseOrderItem     : abap.numc( 5 );
  ServiceEntrySheet     : abap.char( 10 );
  ServiceEntrySheetItem : abap.numc( 5 );
  @Semantics.amount.currencyCode: 'DocumentCurrency'
  PurchaseOrderAmount   : abap.curr( 23, 2 );
  DocumentCurrency      : abap.cuky;
}
