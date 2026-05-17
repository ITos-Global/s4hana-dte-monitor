CLASS zcl_dte_cleanup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    " Limpia las tablas del Monitor DTE.
    " - iv_only_historial = abap_true → sólo zdte_monitor_h (preserva el monitor)
    " - iv_only_historial = abap_false (default) → borra ambas
    CLASS-METHODS truncate_all
      IMPORTING iv_only_historial TYPE abap_bool DEFAULT abap_false
      EXPORTING ev_rows_monitor   TYPE i
                ev_rows_historial TYPE i.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_dte_cleanup IMPLEMENTATION.

  METHOD truncate_all.
    ev_rows_monitor   = 0.
    ev_rows_historial = 0.

    " Borrar historial primero (FK lógica vía composition)
    DELETE FROM zdte_monitor_h.
    ev_rows_historial = sy-dbcnt.

    IF iv_only_historial = abap_true.
      RETURN.
    ENDIF.

    DELETE FROM zdte_monitor.
    ev_rows_monitor = sy-dbcnt.

    " Commit explícito requerido fuera de un BO context
    COMMIT WORK.
  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.
    " Punto de entrada para ejecución vía F9 en ADT (Console Run).
    DATA lv_rows_m TYPE i.
    DATA lv_rows_h TYPE i.

    truncate_all(
      IMPORTING ev_rows_monitor   = lv_rows_m
                ev_rows_historial = lv_rows_h ).

    out->write( |=== Limpieza Monitor DTE ===| ).
    out->write( |zdte_monitor_h: { lv_rows_h } filas borradas| ).
    out->write( |zdte_monitor:   { lv_rows_m } filas borradas| ).
    out->write( |Listo.| ).
  ENDMETHOD.

ENDCLASS.
