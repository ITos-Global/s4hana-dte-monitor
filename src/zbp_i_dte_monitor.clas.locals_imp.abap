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
    LOOP AT keys INTO DATA(ls_auth_key).
      APPEND VALUE #(
        %tky                         = ls_auth_key-%tky
        %update                      = if_abap_behv=>auth-allowed
        %action-Reprocesar           = if_abap_behv=>auth-allowed
        %action-Rechazar             = if_abap_behv=>auth-allowed
        %action-IndicarDocReferencia = if_abap_behv=>auth-allowed
        %action-IndicarPosiciones    = if_abap_behv=>auth-allowed
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD ingest_from_xml.
    " Factory action: parsea el XML, valida tipo permitido y crea el registro
    " en estado '01' (Pendiente). El procesamiento se dispara después por la
    " determination AutoProcess cuando se reciba FechaRecepcionSii.
    DATA(lv_user_ix) = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_date_ix) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time_ix) = cl_abap_context_info=>get_system_time( ).

    LOOP AT keys INTO DATA(ls_key_ix).
      " Extraer campos clave del XML
      DATA(lo_proc_ix) = NEW zcl_dte_processor( ).
      DATA ls_meta TYPE zcl_dte_processor=>ty_dte_meta.
      TRY.
          ls_meta = lo_proc_ix->extract_keys( ls_key_ix-%param-XmlData ).
        CATCH cx_root INTO DATA(lx_ix).
          APPEND VALUE #( %cid = ls_key_ix-%cid ) TO failed-dtemonitor.
          APPEND VALUE #( %cid = ls_key_ix-%cid
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = |Error parseando XML: { lx_ix->get_text( ) }| )
                        ) TO reported-dtemonitor.
          CONTINUE.
      ENDTRY.

      " Filtro: tipo DTE permitido
      IF zcl_dte_processor=>is_tipo_dte_permitido( ls_meta-tipo_dte ) = abap_false.
        APPEND VALUE #( %cid = ls_key_ix-%cid ) TO failed-dtemonitor.
        APPEND VALUE #( %cid = ls_key_ix-%cid
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-warning
                                                      text     = |Tipo de DTE { ls_meta-tipo_dte } no permitido. Registro descartado.| )
                      ) TO reported-dtemonitor.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
        ENTITY DteMonitor
          CREATE FIELDS ( TipoDte Folio Proveedor Sociedad
                          FechaDocumento Moneda MontoNeto MontoExento
                          Iec IvaRecuperable IvaNoRecuperable IvaRetenido
                          TotalDocumento XmlData Estado
                          FechaCreacion HoraCreacion UsuarioCreacion )
          WITH VALUE #( (
            %cid             = ls_key_ix-%cid
            TipoDte          = ls_meta-tipo_dte
            Folio            = ls_meta-folio
            Proveedor        = ls_meta-rut_emisor
            Sociedad         = ls_meta-rut_receptor
            FechaDocumento   = ls_meta-fecha_emision
            Moneda           = ls_meta-moneda
            MontoNeto        = ls_meta-monto_neto
            MontoExento      = ls_meta-monto_exento
            Iec              = ls_meta-iec
            IvaRecuperable   = ls_meta-iva
            IvaNoRecuperable = 0
            IvaRetenido      = ls_meta-iva_retenido
            TotalDocumento   = ls_meta-monto_total
            XmlData          = ls_key_ix-%param-XmlData
            Estado           = '01'
            FechaCreacion    = lv_date_ix
            HoraCreacion     = lv_time_ix
            UsuarioCreacion  = lv_user_ix
          ) )
        MAPPED   DATA(lt_m_ix)
        FAILED   DATA(lt_f_ix)
        REPORTED DATA(lt_r_ix).
    ENDLOOP.

  ENDMETHOD.

  METHOD ingest_from_sii.
    " Factory action: UPSERT por llave. Si el registro existe, sólo actualiza
    " FechaRecepcionSii. Si no existe, lo crea en estado '01' con la FE_RECEP.
    DATA(lv_user_is) = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_date_is) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time_is) = cl_abap_context_info=>get_system_time( ).

    LOOP AT keys INTO DATA(ls_key_is).
      " Filtro: tipo DTE permitido
      IF zcl_dte_processor=>is_tipo_dte_permitido( ls_key_is-%param-TipoDte ) = abap_false.
        APPEND VALUE #( %cid = ls_key_is-%cid ) TO failed-dtemonitor.
        APPEND VALUE #( %cid = ls_key_is-%cid
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-warning
                                                      text     = |Tipo de DTE { ls_key_is-%param-TipoDte } no permitido. Registro descartado.| )
                      ) TO reported-dtemonitor.
        CONTINUE.
      ENDIF.

      " ¿Existe ya el registro?
      SELECT SINGLE @abap_true FROM zdte_monitor
        WHERE tipo_dte  = @ls_key_is-%param-TipoDte
          AND folio     = @ls_key_is-%param-Folio
          AND proveedor = @ls_key_is-%param-Proveedor
        INTO @DATA(lv_exists_is).

      IF sy-subrc = 0.
        " UPDATE: sólo FechaRecepcionSii
        MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
          ENTITY DteMonitor
            UPDATE FIELDS ( FechaRecepcionSii FechaModificacion UsuarioModificacion )
            WITH VALUE #( (
              %tky                = VALUE #( TipoDte   = ls_key_is-%param-TipoDte
                                             Folio     = ls_key_is-%param-Folio
                                             Proveedor = ls_key_is-%param-Proveedor )
              FechaRecepcionSii   = ls_key_is-%param-FechaRecepcionSii
              FechaModificacion   = lv_date_is
              UsuarioModificacion = lv_user_is
            ) ).
      ELSE.
        " CREATE: nuevo registro en estado '01' con FE_RECEP ya cargada
        MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
          ENTITY DteMonitor
            CREATE FIELDS ( TipoDte Folio Proveedor Sociedad
                            FechaDocumento Moneda TotalDocumento
                            FechaRecepcionSii Estado
                            FechaCreacion HoraCreacion UsuarioCreacion )
            WITH VALUE #( (
              %cid              = ls_key_is-%cid
              TipoDte           = ls_key_is-%param-TipoDte
              Folio             = ls_key_is-%param-Folio
              Proveedor         = ls_key_is-%param-Proveedor
              Sociedad          = ls_key_is-%param-Sociedad
              FechaDocumento    = ls_key_is-%param-FechaDocumento
              Moneda            = ls_key_is-%param-Moneda
              TotalDocumento    = ls_key_is-%param-MontoTotal
              FechaRecepcionSii = ls_key_is-%param-FechaRecepcionSii
              Estado            = '01'
              FechaCreacion     = lv_date_is
              HoraCreacion      = lv_time_is
              UsuarioCreacion   = lv_user_is
            ) ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD auto_process.
    " Determination on modify: cuando llega FechaRecepcionSii y el registro
    " está en estado '01', dispara el processor para resolver/contabilizar.
    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_ap)
      FAILED DATA(lt_f_ap).

    DATA(lo_proc) = NEW zcl_dte_processor( ).

    LOOP AT lt_ap INTO DATA(ls_ap).
      " Sólo procesar registros pendientes con fecha de recepción SII
      CHECK ls_ap-Estado            = '01'.
      CHECK ls_ap-FechaRecepcionSii IS NOT INITIAL.

      DATA lv_estado_ap   TYPE zdte_monitor-estado.
      DATA lv_log_ap      TYPE string.
      DATA lv_bukrs_ap    TYPE zdte_monitor-bukrs_sap.
      DATA lv_prov_ap     TYPE zdte_monitor-prov_sap.
      DATA lv_year_em_ap  TYPE zdte_monitor-year_em.
      DATA lv_doc_fact_ap TYPE zdte_monitor-doc_fact.
      DATA lv_year_fc_ap  TYPE zdte_monitor-year_fact.

      lo_proc->process_dte(
        EXPORTING
          iv_tipo_dte  = ls_ap-TipoDte
          iv_folio     = ls_ap-Folio
          iv_proveedor = ls_ap-Proveedor
          iv_sociedad  = ls_ap-Sociedad
          iv_xml_data  = ls_ap-XmlData
        IMPORTING
          ev_estado    = lv_estado_ap
          ev_log       = lv_log_ap
          ev_bukrs     = lv_bukrs_ap
          ev_prov_sap  = lv_prov_ap
          ev_year_em   = lv_year_em_ap
          ev_doc_fact  = lv_doc_fact_ap
          ev_year_fact = lv_year_fc_ap ).

      DATA(lv_user_ap) = cl_abap_context_info=>get_user_technical_name( ).
      DATA(lv_date_ap) = cl_abap_context_info=>get_system_date( ).

      MODIFY ENTITIES OF zi_dte_monitor IN LOCAL MODE
        ENTITY DteMonitor
          UPDATE FIELDS ( Estado LogProcesamiento BukrsSap ProveedorSap
                          AnioEntradaMercancia DocumentoFacturaSap AnioFacturaSap
                          FechaModificacion UsuarioModificacion )
          WITH VALUE #( (
            %tky                 = ls_ap-%tky
            Estado               = lv_estado_ap
            LogProcesamiento     = |[{ lv_date_ap }] { lv_log_ap }|
            BukrsSap             = lv_bukrs_ap
            ProveedorSap         = lv_prov_ap
            AnioEntradaMercancia = lv_year_em_ap
            DocumentoFacturaSap  = lv_doc_fact_ap
            AnioFacturaSap       = lv_year_fc_ap
            FechaModificacion    = lv_date_ap
            UsuarioModificacion  = lv_user_ap
          ) )
        REPORTED DATA(lt_rep_ap).
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

  METHOD get_montos_pendientes.
    " Read-only function: devuelve por posición HES el monto pendiente de
    " facturar (Paso A del spec). El frontend lo muestra para comparar contra
    " el monto del XML antes de contabilizar.
    READ ENTITIES OF zi_dte_monitor IN LOCAL MODE
      ENTITY DteMonitor FIELDS ( OrdenCompra HojaEntradaServicio EntradaMercancia )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_dte_gmp)
      FAILED DATA(lt_f_gmp).

    DATA(lo_proc_gmp) = NEW zcl_dte_processor( ).

    LOOP AT lt_dte_gmp INTO DATA(ls_dte_gmp).
      " Caso HES: lectura por posición desde I_PurchaseOrderHistoryAPI01.
      IF ls_dte_gmp-OrdenCompra IS NOT INITIAL AND ls_dte_gmp-HojaEntradaServicio IS NOT INITIAL.
        DATA(lt_pend_gmp) = lo_proc_gmp->get_pendiente_hes(
          iv_oc  = ls_dte_gmp-OrdenCompra
          iv_hes = ls_dte_gmp-HojaEntradaServicio ).

        LOOP AT lt_pend_gmp INTO DATA(ls_pend_gmp).
          APPEND VALUE #(
            %tky                  = ls_dte_gmp-%tky
            PurchaseOrder         = ls_pend_gmp-purchase_order
            PurchaseOrderItem     = ls_pend_gmp-purchase_order_item
            ServiceEntrySheet     = ls_pend_gmp-service_entry_sheet
            ServiceEntrySheetItem = ls_pend_gmp-service_entry_sheet_item
            PurchaseOrderAmount   = ls_pend_gmp-purchase_order_amount
            DocumentCurrency      = ls_pend_gmp-document_currency
          ) TO result.
        ENDLOOP.

      " TODO Caso EM: implementar consulta análoga sobre I_PurchaseOrderHistoryAPI01
      "      con PurchasingHistoryDocumentType='1' / Category='E' cuando se defina
      "      la regla de parcialidad de EM.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
