CLASS zbp_i_dte_monitor DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zi_dte_monitor.
ENDCLASS.
CLASS zbp_i_dte_monitor IMPLEMENTATION.
ENDCLASS.


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

CLASS lhc_dtemonitor IMPLEMENTATION.

  "============================================================================
  " ACCION: Reprocesar
  " Relanza el flujo completo de validación y contabilización.
  " Aplica a selección múltiple; omite registros ya Aprobados/Contabilizados.
  "============================================================================
  METHOD reprocesar.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_dte)
      FAILED DATA(lt_failed_read).

    LOOP AT lt_dte INTO DATA(ls_dte).

      " Solo procesar registros que NO sean Aprobado (02) ni Contabilizado (06)
      IF ls_dte-Estado = '02' OR ls_dte-Estado = '06'.
        CONTINUE.
      ENDIF.

      " Delegar lógica de negocio a ZCL_DTE_PROCESSOR
      DATA(lo_proc) = NEW zcl_dte_processor( ).
      lo_proc->process_dte(
        EXPORTING
          iv_tipo_dte  = ls_dte-TipoDte
          iv_folio     = ls_dte-Folio
          iv_proveedor = ls_dte-Proveedor
          iv_sociedad  = ls_dte-Sociedad
          iv_xml_data  = ls_dte-XmlData
        IMPORTING
          ev_estado    = DATA(lv_estado)
          ev_log       = DATA(lv_log)
          ev_doc_fact  = DATA(lv_doc_fact)
          ev_year_fact = DATA(lv_year_fact)
      ).

      MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
        ENTITY DteMonitor
        UPDATE FIELDS ( Estado LogProcesamiento
                        DocumentoFacturaSap AnioFacturaSap
                        FechaModificacion UsuarioModificacion )
        WITH VALUE #( (
          %tky                = ls_dte-%tky
          Estado              = lv_estado
          LogProcesamiento    = lv_log
          DocumentoFacturaSap = lv_doc_fact
          AnioFacturaSap      = lv_year_fact
          FechaModificacion   = cl_abap_context_info=>get_system_date( )
          UsuarioModificacion = cl_abap_context_info=>get_user_alias( )
        ) )
        REPORTED DATA(lt_rep).

    ENDLOOP.

    " Devolver estado actualizado al caller (OData response)
    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls IN lt_result
                      ( %tky   = ls-%tky
                        %param = CORRESPONDING #( ls ) ) ).
  ENDMETHOD.

  "============================================================================
  " ACCION: Rechazar
  " Parámetro: ZS_DTE_RECHAZO { Motivo }
  " Cambia estado a 03, registra motivo en log.
  "============================================================================
  METHOD rechazar.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor
      FIELDS ( Estado )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_dte).

    LOOP AT lt_dte INTO DATA(ls_dte).

      IF ls_dte-Estado = '02' OR ls_dte-Estado = '06'.
        CONTINUE.
      ENDIF.

      " Leer parámetro Motivo (viene en %param de la key)
      DATA(lv_motivo) = VALUE #(
        keys[ %tky = ls_dte-%tky ]-%param-Motivo OPTIONAL ).

      IF lv_motivo IS INITIAL.
        lv_motivo = 'Rechazado manualmente por usuario'.
      ENDIF.

      MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
        ENTITY DteMonitor
        UPDATE FIELDS ( Estado LogProcesamiento
                        FechaModificacion UsuarioModificacion )
        WITH VALUE #( (
          %tky                = ls_dte-%tky
          Estado              = '03'
          LogProcesamiento    = |Rechazado. Motivo: { lv_motivo }|
          FechaModificacion   = cl_abap_context_info=>get_system_date( )
          UsuarioModificacion = cl_abap_context_info=>get_user_alias( )
        ) ).

    ENDLOOP.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls IN lt_result
                      ( %tky   = ls-%tky
                        %param = CORRESPONDING #( ls ) ) ).
  ENDMETHOD.

  "============================================================================
  " ACCION: IndicarDocReferencia
  " Parámetro: ZS_DTE_DOC_REF { OrdenCompra, HojaEntradaServicio,
  "                              EntradaMercancia, AnioEntradaMercancia,
  "                              FolioReferencia }
  " Persiste los documentos de referencia y dispara reproceso.
  "============================================================================
  METHOD indicar_doc_referencia.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor
      FIELDS ( Estado )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_dte).

    LOOP AT lt_dte INTO DATA(ls_dte).

      DATA(ls_param) = VALUE #(
        keys[ %tky = ls_dte-%tky ]-%param OPTIONAL ).

      " Actualizar campos de referencia en el registro
      MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
        ENTITY DteMonitor
        UPDATE FIELDS ( OrdenCompra HojaEntradaServicio
                        EntradaMercancia AnioEntradaMercancia
                        FolioReferencia )
        WITH VALUE #( (
          %tky                 = ls_dte-%tky
          OrdenCompra          = ls_param-OrdenCompra
          HojaEntradaServicio  = ls_param-HojaEntradaServicio
          EntradaMercancia     = ls_param-EntradaMercancia
          AnioEntradaMercancia = ls_param-AnioEntradaMercancia
          FolioReferencia      = ls_param-FolioReferencia
        ) ).

    ENDLOOP.

    " Reprocesar con los nuevos documentos de referencia
    reprocesar( IMPORTING keys = keys RESULT result ).

  ENDMETHOD.

  "============================================================================
  " ACCION: IndicarPosiciones
  " Parámetro: ZS_DTE_POSICION (una posición por llamada; el UI envía la
  " posición confirmada para el DTE parcial)
  " Contabiliza con las cantidades/montos que el usuario eligió.
  "============================================================================
  METHOD indicar_posiciones.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_dte).

    LOOP AT lt_dte INTO DATA(ls_dte).

      DATA(ls_param) = VALUE #(
        keys[ %tky = ls_dte-%tky ]-%param OPTIONAL ).

      " Construir tabla de posiciones con la única posición enviada
      DATA(lt_posiciones) = VALUE zcl_dte_processor=>tt_posiciones( (
        posicion         = ls_param-Posicion
        material         = ls_param-Material
        cantidad         = ls_param-CantidadFacturar
        unidad           = ls_param-UnidadMedida
      ) ).

      DATA(lo_proc) = NEW zcl_dte_processor( ).
      lo_proc->process_dte_with_positions(
        EXPORTING
          iv_tipo_dte   = ls_dte-TipoDte
          iv_folio      = ls_dte-Folio
          iv_proveedor  = ls_dte-Proveedor
          iv_sociedad   = ls_dte-Sociedad
          iv_xml_data   = ls_dte-XmlData
          it_posiciones = lt_posiciones
        IMPORTING
          ev_estado     = DATA(lv_estado)
          ev_log        = DATA(lv_log)
          ev_doc_fact   = DATA(lv_doc_fact)
          ev_year_fact  = DATA(lv_year_fact)
      ).

      MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
        ENTITY DteMonitor
        UPDATE FIELDS ( Estado LogProcesamiento
                        DocumentoFacturaSap AnioFacturaSap
                        FechaModificacion UsuarioModificacion )
        WITH VALUE #( (
          %tky                = ls_dte-%tky
          Estado              = lv_estado
          LogProcesamiento    = lv_log
          DocumentoFacturaSap = lv_doc_fact
          AnioFacturaSap      = lv_year_fact
          FechaModificacion   = cl_abap_context_info=>get_system_date( )
          UsuarioModificacion = cl_abap_context_info=>get_user_alias( )
        ) ).

    ENDLOOP.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls IN lt_result
                      ( %tky   = ls-%tky
                        %param = CORRESPONDING #( ls ) ) ).
  ENDMETHOD.

  "============================================================================
  " DETERMINACION: SetDiasPendientes
  " Calcula días transcurridos desde FechaRecepcionSii para estados 01 y 04.
  "============================================================================
  METHOD set_dias_pendientes.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor
      FIELDS ( FechaRecepcionSii Estado )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_dte).

    DATA(lv_hoy) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lt_dte INTO DATA(ls_dte).
      IF ls_dte-Estado <> '01' AND ls_dte-Estado <> '04'.
        CONTINUE.
      ENDIF.

      CHECK ls_dte-FechaRecepcionSii IS NOT INITIAL.

      DATA(lv_dias) = CONV abap_int4( lv_hoy - ls_dte-FechaRecepcionSii ).

      MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
        ENTITY DteMonitor
        UPDATE FIELDS ( DiasPendientes )
        WITH VALUE #( (
          %tky           = ls_dte-%tky
          DiasPendientes = lv_dias
        ) ).
    ENDLOOP.
  ENDMETHOD.

  "============================================================================
  " DETERMINACION: CrearHistorial
  " Inserta registro en ZDTE_MONITOR_H al persistir un cambio de estado.
  "============================================================================
  METHOD crear_historial.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor
      FIELDS ( Estado LogProcesamiento )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_dte).

    LOOP AT lt_dte INTO DATA(ls_dte).

      " Número de secuencia siguiente para este DTE
      SELECT MAX( seqno )
        FROM zdte_monitor_h
        WHERE tipo_dte  = @ls_dte-TipoDte
          AND folio     = @ls_dte-Folio
          AND proveedor = @ls_dte-Proveedor
        INTO @DATA(lv_max_seq).

      " Convertir fecha+hora a timestamp
      DATA(lv_ts) = CONV tzntstmps(
        cl_abap_context_info=>get_system_date( ) &&
        cl_abap_context_info=>get_system_time( )
      ).

      INSERT zdte_monitor_h FROM @(
        VALUE zdte_monitor_h(
          mandt        = sy-mandt
          tipo_dte     = ls_dte-TipoDte
          folio        = ls_dte-Folio
          proveedor    = ls_dte-Proveedor
          seqno        = lv_max_seq + 1
          timestamp    = lv_ts
          estado_nuevo = ls_dte-Estado
          usrname      = cl_abap_context_info=>get_user_alias( )
          texto        = ls_dte-LogProcesamiento
        )
      ).

    ENDLOOP.
  ENDMETHOD.

  "============================================================================
  " VALIDACION: ValidateDocReferencia
  " Verifica que la OC informada exista en EKKO y corresponda a la sociedad.
  "============================================================================
  METHOD validate_doc_referencia.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor
      FIELDS ( OrdenCompra Sociedad )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_dte).

    LOOP AT lt_dte INTO DATA(ls_dte).

      " Sin documentos de referencia → el processor gestionará la lógica
      IF ls_dte-OrdenCompra IS INITIAL.
        CONTINUE.
      ENDIF.

      " Verificar existencia de OC en EKKO (no anulada, sociedad correcta)
      SELECT SINGLE @abap_true
        FROM ekko
        WHERE ebeln = @ls_dte-OrdenCompra
          AND bukrs = @ls_dte-Sociedad
          AND loekz = @space
        INTO @DATA(lv_existe).

      IF lv_existe <> abap_true.
        APPEND VALUE #(
          %tky        = ls_dte-%tky
          %state_area = 'VALIDATE_DOC_REF'
        ) TO failed-dtemonitor.

        APPEND VALUE #(
          %tky        = ls_dte-%tky
          %state_area = 'VALIDATE_DOC_REF'
          %msg        = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error
                          text     = |OC { ls_dte-OrdenCompra } no existe|
                                  && | o está anulada en sociedad { ls_dte-Sociedad }.|
                        )
        ) TO reported-dtemonitor.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  "============================================================================
  " FEATURE CONTROL: habilitar/deshabilitar acciones y campos según estado
  "============================================================================
  METHOD get_instance_features.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor
      FIELDS ( Estado )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_dte)
      FAILED DATA(lt_failed).

    result = VALUE #( FOR ls IN lt_dte
      LET " Aprobado o Contabilizado → no se puede reprocesar ni rechazar
          bBloqueado = xsdbool( ls-Estado = '02' OR ls-Estado = '06' )
          " Solo estado 04 (Por rechazar) permite indicar doc. ref. y posiciones
          bPorRech   = xsdbool( ls-Estado = '04' )
      IN (
        %tky = ls-%tky

        %action-Reprocesar = COND #(
          WHEN bBloqueado = abap_true
          THEN if_abap_behv=>fc-o-disabled
          ELSE if_abap_behv=>fc-o-enabled )

        %action-Rechazar = COND #(
          WHEN bBloqueado = abap_true
          THEN if_abap_behv=>fc-o-disabled
          ELSE if_abap_behv=>fc-o-enabled )

        %action-IndicarDocReferencia = COND #(
          WHEN bPorRech = abap_true
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled )

        %action-IndicarPosiciones = COND #(
          WHEN bPorRech = abap_true
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled )

        " Campos de referencia: editables solo en estado 04
        %field-OrdenCompra = COND #(
          WHEN bPorRech = abap_true
          THEN if_abap_behv=>fc-f-unrestricted
          ELSE if_abap_behv=>fc-f-read_only )

        %field-HojaEntradaServicio = COND #(
          WHEN bPorRech = abap_true
          THEN if_abap_behv=>fc-f-unrestricted
          ELSE if_abap_behv=>fc-f-read_only )

        %field-EntradaMercancia = COND #(
          WHEN bPorRech = abap_true
          THEN if_abap_behv=>fc-f-unrestricted
          ELSE if_abap_behv=>fc-f-read_only )

        %field-AnioEntradaMercancia = COND #(
          WHEN bPorRech = abap_true
          THEN if_abap_behv=>fc-f-unrestricted
          ELSE if_abap_behv=>fc-f-read_only )

        %field-FolioReferencia = COND #(
          WHEN bPorRech = abap_true
          THEN if_abap_behv=>fc-f-unrestricted
          ELSE if_abap_behv=>fc-f-read_only )
      )
    ).
  ENDMETHOD.

  "============================================================================
  " AUTHORIZATION: verifica acceso por sociedad (complementa el DCL)
  "============================================================================
  METHOD get_instance_authorizations.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor
      FIELDS ( Sociedad )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_dte).

    LOOP AT lt_dte INTO DATA(ls_dte).
      AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
        ID 'BUKRS' FIELD ls_dte-Sociedad
        ID 'ACTVT' FIELD '02'.

      DATA(lv_auth) = COND #(
        WHEN sy-subrc = 0
        THEN if_abap_behv=>auth-allowed
        ELSE if_abap_behv=>auth-unauthorized ).

      APPEND VALUE #(
        %tky                          = ls_dte-%tky
        %update                       = lv_auth
        %action-Reprocesar            = lv_auth
        %action-Rechazar              = lv_auth
        %action-IndicarDocReferencia  = lv_auth
        %action-IndicarPosiciones     = lv_auth
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

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

CLASS lsc_zi_dte_monitor IMPLEMENTATION.
  METHOD finalize.
    " El managed runtime calcula campos ETG y auditoría automáticamente
  ENDMETHOD.

  METHOD check_before_save.
    " Validaciones transversales antes del commit
  ENDMETHOD.

  METHOD save.
    " Managed runtime gestiona el save con la tabla persistente zdte_monitor
  ENDMETHOD.

  METHOD cleanup.
  ENDMETHOD.
ENDCLASS.
