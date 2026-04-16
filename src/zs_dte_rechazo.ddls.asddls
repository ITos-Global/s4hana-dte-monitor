@EndUserText.label: 'Parametro Accion Rechazar DTE'
define abstract entity ZS_DTE_RECHAZO {
  "@<Motivo> Texto libre que indica la razón del rechazo manual"
  Motivo : abap.char( 200 );
}
