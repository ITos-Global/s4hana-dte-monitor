*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* temporary local helper classes (prefixed with LTY_, LCL_, LIF_, LST_)

"##############################################################################
" LOCAL HANDLER — Acciones, Determinaciones, Validaciones, Feature/Auth control
"##############################################################################
CLASS lhc_dtemonitor DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    "--------------------------------------------------------------------------
    " Acciones
    "--------------------------------------------------------------------------
    METHODS reprocesar
      FOR ACTION DteMonitor~Reprocesar
      IMPORTING keys FOR DteMonitor~Reprocesar result.

    METHODS rechazar
      FOR ACTION DteMonitor~Rechazar
      IMPORTING keys FOR DteMonitor~Rechazar result.

    METHODS indicar_doc_referencia
      FOR ACTION DteMonitor~IndicarDocReferencia
      IMPORTING keys FOR DteMonitor~IndicarDocReferencia result.

    METHODS indicar_posiciones
      FOR ACTION DteMonitor~IndicarPosiciones
      IMPORTING keys FOR DteMonitor~IndicarPosiciones result.

    "--------------------------------------------------------------------------
    " Determinaciones
    "--------------------------------------------------------------------------
    METHODS set_dias_pendientes
      FOR DETERMINATION DteMonitor~SetDiasPendientes
      IMPORTING keys FOR DteMonitor.

    METHODS crear_historial
      FOR DETERMINATION DteMonitor~CrearHistorial
      IMPORTING keys FOR DteMonitor.

    "--------------------------------------------------------------------------
    " Validaciones
    "--------------------------------------------------------------------------
    METHODS validate_doc_referencia
      FOR VALIDATION DteMonitor~ValidateDocReferencia
      IMPORTING keys FOR DteMonitor.

    "--------------------------------------------------------------------------
    " Feature control
    "--------------------------------------------------------------------------
    METHODS get_instance_features
      FOR INSTANCE FEATURES OF DteMonitor
      IMPORTING keys REQUEST requested_features
      RESULT result.

    "--------------------------------------------------------------------------
    " Authorization
    "--------------------------------------------------------------------------
    METHODS get_instance_authorizations
      FOR INSTANCE AUTHORIZATION OF DteMonitor
      IMPORTING keys REQUEST requested_authorizations
      RESULT result.

ENDCLASS.

"##############################################################################
" LOCAL SAVER
"##############################################################################
CLASS lsc_zi_dte_monitor DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS finalize          REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save              REDEFINITION.
    METHODS cleanup           REDEFINITION.
ENDCLASS.
