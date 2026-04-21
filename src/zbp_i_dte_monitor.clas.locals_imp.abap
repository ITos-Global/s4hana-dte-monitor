CLASS lhc_dtemonitor IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor FIELDS ( Estado )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_feat)
      FAILED DATA(lt_f_feat).

    DATA ls_res_feat LIKE LINE OF result.

    LOOP AT lt_feat INTO DATA(ls_feat).
      CLEAR ls_res_feat.
      ls_res_feat-%tky = ls_feat-%tky.

      IF ls_feat-Estado = '02' OR ls_feat-Estado = '06'.
        ls_res_feat-%features-%action-Reprocesar           = if_abap_behv=>fc-o-disabled.
        ls_res_feat-%features-%action-Rechazar             = if_abap_behv=>fc-o-disabled.
        ls_res_feat-%features-%action-IndicarDocReferencia = if_abap_behv=>fc-o-disabled.
        ls_res_feat-%features-%action-IndicarPosiciones    = if_abap_behv=>fc-o-disabled.
      ELSE.
        ls_res_feat-%features-%action-Reprocesar = if_abap_behv=>fc-o-enabled.
        ls_res_feat-%features-%action-Rechazar   = COND #(
          WHEN ls_feat-Estado = '03' THEN if_abap_behv=>fc-o-disabled
          ELSE if_abap_behv=>fc-o-enabled ).
        ls_res_feat-%features-%action-IndicarDocReferencia = COND #(
          WHEN ls_feat-Estado = '04' THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled ).
        ls_res_feat-%features-%action-IndicarPosiciones = COND #(
          WHEN ls_feat-Estado = '04' THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled ).
      ENDIF.

      IF ls_feat-Estado = '04'.
        ls_res_feat-%features-%field-OrdenCompra          = if_abap_behv=>fc-f-unrestricted.
        ls_res_feat-%features-%field-HojaEntradaServicio  = if_abap_behv=>fc-f-unrestricted.
        ls_res_feat-%features-%field-EntradaMercancia     = if_abap_behv=>fc-f-unrestricted.
        ls_res_feat-%features-%field-AnioEntradaMercancia = if_abap_behv=>fc-f-unrestricted.
        ls_res_feat-%features-%field-FolioReferencia      = if_abap_behv=>fc-f-unrestricted.
      ELSE.
        ls_res_feat-%features-%field-OrdenCompra          = if_abap_behv=>fc-f-read_only.
        ls_res_feat-%features-%field-HojaEntradaServicio  = if_abap_behv=>fc-f-read_only.
        ls_res_feat-%features-%field-EntradaMercancia     = if_abap_behv=>fc-f-read_only.
        ls_res_feat-%features-%field-AnioEntradaMercancia = if_abap_behv=>fc-f-read_only.
        ls_res_feat-%features-%field-FolioReferencia      = if_abap_behv=>fc-f-read_only.
      ENDIF.

      APPEND ls_res_feat TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_authorizations.
    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor FIELDS ( Sociedad )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_auth)
      FAILED DATA(lt_f_auth).

    LOOP AT lt_auth INTO DATA(ls_auth).
      AUTHORITY-CHECK OBJECT 'F_BKPF_BUK'
        ID 'BUKRS' FIELD ls_auth-Sociedad
        ID 'ACTVT' FIELD '02'.
      DATA(lv_auth) = COND #(
        WHEN sy-subrc = 0 THEN if_abap_behv=>auth-allowed
        ELSE                   if_abap_behv=>auth-unauthorized ).
      APPEND VALUE #(
        %tky                         = ls_auth-%tky
        %update                      = lv_auth
        %action-Reprocesar           = lv_auth
        %action-Rechazar             = lv_auth
        %action-IndicarDocReferencia = lv_auth
        %action-IndicarPosiciones    = lv_auth
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD reprocesar.
    DATA(lv_user_rep) = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_date_rep) = cl_abap_context_info=>get_system_date( ).

    LOOP AT keys INTO DATA(ls_key_rep).
      MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
        ENTITY DteMonitor
          UPDATE FIELDS ( Estado LogProcesamiento FechaModificacion UsuarioModificacion )
          WITH VALUE #( (
            %tky                = ls_key_rep-%tky
            Estado              = '01'
            LogProcesamiento    = |[{ lv_date_rep }] Reproceso manual por { lv_user_rep }.|
            FechaModificacion   = lv_date_rep
            UsuarioModificacion = lv_user_rep
          ) )
        REPORTED reported
        FAILED   failed.
    ENDLOOP.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_res_rep)
      FAILED DATA(lt_f_rep).

    LOOP AT lt_res_rep INTO DATA(ls_res_rep).
      APPEND VALUE #(
        %tky   = ls_res_rep-%tky
        %param = CORRESPONDING #( ls_res_rep )
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD rechazar.
    DATA(lv_user_rec) = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_date_rec) = cl_abap_context_info=>get_system_date( ).

    LOOP AT keys INTO DATA(ls_key_rec).
      MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
        ENTITY DteMonitor
          UPDATE FIELDS ( Estado LogProcesamiento FechaModificacion UsuarioModificacion )
          WITH VALUE #( (
            %tky                = ls_key_rec-%tky
            Estado              = '03'
            LogProcesamiento    = |[{ lv_date_rec }] Rechazado por { lv_user_rec }. Motivo: { ls_key_rec-%param-Motivo }|
            FechaModificacion   = lv_date_rec
            UsuarioModificacion = lv_user_rec
          ) )
        REPORTED reported
        FAILED   failed.
    ENDLOOP.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_res_rec)
      FAILED DATA(lt_f_rec).

    LOOP AT lt_res_rec INTO DATA(ls_res_rec).
      APPEND VALUE #(
        %tky   = ls_res_rec-%tky
        %param = CORRESPONDING #( ls_res_rec )
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD indicar_doc_referencia.
    DATA(lv_user_idr) = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_date_idr) = cl_abap_context_info=>get_system_date( ).

    LOOP AT keys INTO DATA(ls_key_idr).
      MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
        ENTITY DteMonitor
          UPDATE FIELDS ( OrdenCompra HojaEntradaServicio
                          EntradaMercancia AnioEntradaMercancia FolioReferencia
                          Estado LogProcesamiento FechaModificacion UsuarioModificacion )
          WITH VALUE #( (
            %tky                 = ls_key_idr-%tky
            OrdenCompra          = ls_key_idr-%param-OrdenCompra
            HojaEntradaServicio  = ls_key_idr-%param-HojaEntradaServicio
            EntradaMercancia     = ls_key_idr-%param-EntradaMercancia
            AnioEntradaMercancia = ls_key_idr-%param-AnioEntradaMercancia
            FolioReferencia      = ls_key_idr-%param-FolioReferencia
            Estado               = '01'
            LogProcesamiento     = |[{ lv_date_idr }] Doc. referencia indicado por { lv_user_idr }.|
            FechaModificacion    = lv_date_idr
            UsuarioModificacion  = lv_user_idr
          ) )
        REPORTED reported
        FAILED   failed.
    ENDLOOP.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_res_idr)
      FAILED DATA(lt_f_idr).

    LOOP AT lt_res_idr INTO DATA(ls_res_idr).
      APPEND VALUE #(
        %tky   = ls_res_idr-%tky
        %param = CORRESPONDING #( ls_res_idr )
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD indicar_posiciones.
    DATA(lv_user_ip) = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_date_ip) = cl_abap_context_info=>get_system_date( ).

    LOOP AT keys INTO DATA(ls_key_ip).
      MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
        ENTITY DteMonitor
          UPDATE FIELDS ( Estado LogProcesamiento FechaModificacion UsuarioModificacion )
          WITH VALUE #( (
            %tky                = ls_key_ip-%tky
            Estado              = '01'
            LogProcesamiento    = |[{ lv_date_ip }] Posicion { ls_key_ip-%param-Posicion } confirmada por { lv_user_ip }.|
            FechaModificacion   = lv_date_ip
            UsuarioModificacion = lv_user_ip
          ) )
        REPORTED reported
        FAILED   failed.
    ENDLOOP.

    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_res_ip)
      FAILED DATA(lt_f_ip).

    LOOP AT lt_res_ip INTO DATA(ls_res_ip).
      APPEND VALUE #(
        %tky   = ls_res_ip-%tky
        %param = CORRESPONDING #( ls_res_ip )
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD set_dias_pendientes.
    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor FIELDS ( FechaRecepcionSii Estado )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_sdp)
      FAILED DATA(lt_f_sdp).

    DATA(lv_hoy) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lt_sdp INTO DATA(ls_sdp).
      IF ls_sdp-FechaRecepcionSii IS INITIAL.         CONTINUE. ENDIF.
      IF ls_sdp-Estado <> '01' AND ls_sdp-Estado <> '04'. CONTINUE. ENDIF.

      MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
        ENTITY DteMonitor
          UPDATE FIELDS ( DiasPendientes )
          WITH VALUE #( (
            %tky           = ls_sdp-%tky
            DiasPendientes = lv_hoy - ls_sdp-FechaRecepcionSii
          ) )
        REPORTED DATA(lt_rep_sdp)
        FAILED   DATA(lt_fail_sdp).
    ENDLOOP.
  ENDMETHOD.

  METHOD crear_historial.
    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor FIELDS ( Estado LogProcesamiento )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ch)
      FAILED DATA(lt_f_ch).

    DATA lv_ts_ch   TYPE tzntstmps.
    DATA lv_max_ch  TYPE n LENGTH 3.
    DATA lv_next_ch TYPE n LENGTH 3.
    GET TIME STAMP FIELD lv_ts_ch.
    DATA(lv_usr_ch) = cl_abap_context_info=>get_user_technical_name( ).

    DATA lt_hist TYPE TABLE FOR CREATE zi_dte_monitor\_historial.

    LOOP AT lt_ch INTO DATA(ls_ch).
      SELECT SINGLE estado FROM zdte_monitor
        WHERE tipo_dte  = @ls_ch-TipoDte
          AND folio     = @ls_ch-Folio
          AND proveedor = @ls_ch-Proveedor
        INTO @DATA(lv_ant_ch).

      IF sy-subrc <> 0.
        lv_ant_ch = ''.
      ELSEIF lv_ant_ch = ls_ch-Estado.
        CONTINUE.
      ENDIF.

      SELECT MAX( seqno ) FROM zdte_monitor_h
        WHERE tipo_dte  = @ls_ch-TipoDte
          AND folio     = @ls_ch-Folio
          AND proveedor = @ls_ch-Proveedor
        INTO @lv_max_ch.
      lv_next_ch = lv_max_ch + 1.

      APPEND VALUE #(
        %tky    = ls_ch-%tky
        %target = VALUE #( (
          %cid           = |H_{ ls_ch-TipoDte }{ ls_ch-Folio }{ ls_ch-Proveedor }{ lv_next_ch }|
          SeqNo          = lv_next_ch
          Timestamp      = lv_ts_ch
          EstadoAnterior = lv_ant_ch
          EstadoNuevo    = ls_ch-Estado
          Usuario        = lv_usr_ch
          Descripcion    = |{ lv_ant_ch } → { ls_ch-Estado }. { ls_ch-LogProcesamiento }|
        ) )
      ) TO lt_hist.
    ENDLOOP.

    CHECK lt_hist IS NOT INITIAL.
    MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor CREATE BY \_historial
        FIELDS ( SeqNo Timestamp EstadoAnterior EstadoNuevo Usuario Descripcion )
        WITH lt_hist
      REPORTED DATA(lt_rep_ch)
      FAILED   DATA(lt_fail_ch).
  ENDMETHOD.

  METHOD validate_doc_referencia.
    " TODO: Agregar validación de OC contra API liberada cuando esté disponible.
    " I_PurchaseOrder no está en contrato C1 para uso directo en behavior pools.
    " Por ahora la validación pasa siempre; el procesador ZCL_DTE_PROCESSOR
    " realizará la verificación en tiempo de ejecución al contabilizar.
  ENDMETHOD.

ENDCLASS.
