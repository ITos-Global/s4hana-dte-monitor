CLASS zcl_dte_processor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_posicion,
             posicion TYPE ebelp,
             material TYPE matnr,
             cantidad TYPE menge_d,
             unidad   TYPE meins,
           END OF ty_posicion.
    TYPES tt_posiciones TYPE STANDARD TABLE OF ty_posicion WITH DEFAULT KEY.

    METHODS process_dte
      IMPORTING
        iv_tipo_dte  TYPE zdte_monitor-tipo_dte
        iv_folio     TYPE zdte_monitor-folio
        iv_proveedor TYPE zdte_monitor-proveedor
        iv_sociedad  TYPE zdte_monitor-sociedad
        iv_xml_data  TYPE string
      EXPORTING
        ev_estado    TYPE zdte_monitor-estado
        ev_log       TYPE string
        ev_doc_fact  TYPE zdte_monitor-doc_fact
        ev_year_fact TYPE zdte_monitor-year_fact.

    METHODS process_dte_with_positions
      IMPORTING
        iv_tipo_dte   TYPE zdte_monitor-tipo_dte
        iv_folio      TYPE zdte_monitor-folio
        iv_proveedor  TYPE zdte_monitor-proveedor
        iv_sociedad   TYPE zdte_monitor-sociedad
        iv_xml_data   TYPE string
        it_posiciones TYPE tt_posiciones
      EXPORTING
        ev_estado     TYPE zdte_monitor-estado
        ev_log        TYPE string
        ev_doc_fact   TYPE zdte_monitor-doc_fact
        ev_year_fact  TYPE zdte_monitor-year_fact.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_dte_xml,
             tipo_dte      TYPE numc3,
             folio         TYPE char20,
             rut_emisor    TYPE char12,
             rut_receptor  TYPE char12,
             razon_social  TYPE char100,
             fecha_emision TYPE dats,
             moneda        TYPE waers,
             monto_neto    TYPE p LENGTH 15 DECIMALS 2,
             monto_exento  TYPE p LENGTH 15 DECIMALS 2,
             iva           TYPE p LENGTH 15 DECIMALS 2,
             iec           TYPE p LENGTH 15 DECIMALS 2,
             iva_no_rec    TYPE p LENGTH 15 DECIMALS 2,
             iva_retenido  TYPE p LENGTH 15 DECIMALS 2,
             monto_total   TYPE p LENGTH 15 DECIMALS 2,
             oc_ref        TYPE ebeln,
             hes_ref       TYPE belnr_d,
             em_ref        TYPE belnr_d,
             folio_ref     TYPE char20,
             tiene_ref     TYPE abap_bool,
           END OF ty_dte_xml.

    TYPES: BEGIN OF ty_referencia,
             nro_lin    TYPE i,
             tipo_doc   TYPE char10,
             folio_ref  TYPE char20,
           END OF ty_referencia.
    TYPES tt_referencias TYPE STANDARD TABLE OF ty_referencia WITH DEFAULT KEY.

    METHODS parse_xml
      IMPORTING iv_xml        TYPE string
      RETURNING VALUE(rs_dte) TYPE ty_dte_xml
      RAISING   cx_abap_invalid_value.

    METHODS normalize_rut
      IMPORTING iv_rut        TYPE string
      RETURNING VALUE(rv_rut) TYPE string.

    METHODS validate_referencia_xml
      IMPORTING is_dte      TYPE ty_dte_xml
      EXPORTING ev_ok       TYPE abap_bool
                ev_mensaje  TYPE string.

    METHODS validate_doc_sap
      IMPORTING is_dte      TYPE ty_dte_xml
                iv_sociedad TYPE bukrs
      EXPORTING ev_ok       TYPE abap_bool
                ev_mensaje  TYPE string.

    METHODS validate_hes_oc
      IMPORTING is_dte      TYPE ty_dte_xml
      EXPORTING ev_ok       TYPE abap_bool
                ev_mensaje  TYPE string.

    METHODS validate_sociedad
      IMPORTING is_dte      TYPE ty_dte_xml
                iv_sociedad TYPE bukrs
      EXPORTING ev_ok       TYPE abap_bool
                ev_mensaje  TYPE string.

    METHODS validate_proveedor
      IMPORTING is_dte      TYPE ty_dte_xml
                iv_sociedad TYPE bukrs
      EXPORTING ev_ok       TYPE abap_bool
                ev_mensaje  TYPE string.

    METHODS validate_monto
      IMPORTING is_dte      TYPE ty_dte_xml
                iv_sociedad TYPE bukrs
      EXPORTING ev_ok       TYPE abap_bool
                ev_mensaje  TYPE string.

    METHODS contabilizar
      IMPORTING is_dte        TYPE ty_dte_xml
                iv_sociedad   TYPE bukrs
                it_posiciones TYPE tt_posiciones OPTIONAL
      EXPORTING ev_doc_fact   TYPE belnr_d
                ev_year_fact  TYPE gjahr
                ev_ok         TYPE abap_bool
                ev_mensaje    TYPE string.

    METHODS get_rut_sociedad
      IMPORTING iv_sociedad    TYPE bukrs
      RETURNING VALUE(rv_rut)  TYPE string.

    METHODS get_rut_proveedor
      IMPORTING iv_lifnr       TYPE lifnr
      RETURNING VALUE(rv_rut)  TYPE string.

    METHODS get_monto_pendiente
      IMPORTING is_dte              TYPE ty_dte_xml
                iv_sociedad         TYPE bukrs
      RETURNING VALUE(rv_monto_clp) TYPE wrbtr.

    METHODS get_tipo_cambio
      IMPORTING iv_moneda    TYPE waers
                iv_fecha     TYPE dats
      RETURNING VALUE(rv_tc) TYPE wrbtr.

    METHODS get_config
      IMPORTING iv_parametro   TYPE zdte_config-parametro
      RETURNING VALUE(rv_valor) TYPE zdte_config-valor_num.

ENDCLASS.

CLASS zcl_dte_processor IMPLEMENTATION.

  METHOD process_dte.
    ev_estado    = '05'.
    ev_log       = ''.
    ev_doc_fact  = ''.
    ev_year_fact = ''.

    DATA ls_dte TYPE ty_dte_xml.
    TRY.
        ls_dte = parse_xml( iv_xml_data ).
      CATCH cx_dynamic_check INTO DATA(lx).
        ev_estado = '05'.
        ev_log    = |Error al parsear XML del DTE: { lx->get_text( ) }|.
        RETURN.
    ENDTRY.

    DATA lv_ok  TYPE abap_bool.
    DATA lv_msg TYPE string.

    validate_referencia_xml(
      EXPORTING is_dte    = ls_dte
      IMPORTING ev_ok     = lv_ok
                ev_mensaje = lv_msg ).
    IF lv_ok = abap_false.
      ev_estado = '04'. ev_log = lv_msg. RETURN.
    ENDIF.

    validate_doc_sap(
      EXPORTING is_dte     = ls_dte
                iv_sociedad = iv_sociedad
      IMPORTING ev_ok      = lv_ok
                ev_mensaje  = lv_msg ).
    IF lv_ok = abap_false.
      ev_estado = '04'. ev_log = lv_msg. RETURN.
    ENDIF.

    validate_hes_oc(
      EXPORTING is_dte    = ls_dte
      IMPORTING ev_ok     = lv_ok
                ev_mensaje = lv_msg ).
    IF lv_ok = abap_false.
      ev_estado = '04'. ev_log = lv_msg. RETURN.
    ENDIF.

    validate_sociedad(
      EXPORTING is_dte     = ls_dte
                iv_sociedad = iv_sociedad
      IMPORTING ev_ok      = lv_ok
                ev_mensaje  = lv_msg ).
    IF lv_ok = abap_false.
      ev_estado = '04'. ev_log = lv_msg. RETURN.
    ENDIF.

    validate_proveedor(
      EXPORTING is_dte     = ls_dte
                iv_sociedad = iv_sociedad
      IMPORTING ev_ok      = lv_ok
                ev_mensaje  = lv_msg ).
    IF lv_ok = abap_false.
      ev_estado = '04'. ev_log = lv_msg. RETURN.
    ENDIF.

    validate_monto(
      EXPORTING is_dte     = ls_dte
                iv_sociedad = iv_sociedad
      IMPORTING ev_ok      = lv_ok
                ev_mensaje  = lv_msg ).
    IF lv_ok = abap_false.
      ev_estado = '04'. ev_log = lv_msg. RETURN.
    ENDIF.

    contabilizar(
      EXPORTING is_dte       = ls_dte
                iv_sociedad  = iv_sociedad
      IMPORTING ev_doc_fact  = ev_doc_fact
                ev_year_fact = ev_year_fact
                ev_ok        = lv_ok
                ev_mensaje   = lv_msg ).

    ev_estado = COND #( WHEN lv_ok = abap_true THEN '06' ELSE '05' ).
    ev_log    = lv_msg.
  ENDMETHOD.

  METHOD process_dte_with_positions.
    ev_estado    = '05'.
    ev_log       = ''.
    ev_doc_fact  = ''.
    ev_year_fact = ''.

    DATA ls_dte TYPE ty_dte_xml.
    TRY.
        ls_dte = parse_xml( iv_xml_data ).
      CATCH cx_dynamic_check INTO DATA(lx).
        ev_estado = '05'.
        ev_log    = |Error al parsear XML: { lx->get_text( ) }|.
        RETURN.
    ENDTRY.

    DATA lv_ok  TYPE abap_bool.
    DATA lv_msg TYPE string.

    validate_referencia_xml( EXPORTING is_dte = ls_dte IMPORTING ev_ok = lv_ok ev_mensaje = lv_msg ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    validate_doc_sap( EXPORTING is_dte = ls_dte iv_sociedad = iv_sociedad IMPORTING ev_ok = lv_ok ev_mensaje = lv_msg ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    validate_hes_oc( EXPORTING is_dte = ls_dte IMPORTING ev_ok = lv_ok ev_mensaje = lv_msg ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    validate_sociedad( EXPORTING is_dte = ls_dte iv_sociedad = iv_sociedad IMPORTING ev_ok = lv_ok ev_mensaje = lv_msg ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    validate_proveedor( EXPORTING is_dte = ls_dte iv_sociedad = iv_sociedad IMPORTING ev_ok = lv_ok ev_mensaje = lv_msg ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    contabilizar(
      EXPORTING is_dte        = ls_dte
                iv_sociedad   = iv_sociedad
                it_posiciones = it_posiciones
      IMPORTING ev_doc_fact   = ev_doc_fact
                ev_year_fact  = ev_year_fact
                ev_ok         = lv_ok
                ev_mensaje    = lv_msg ).

    ev_estado = COND #( WHEN lv_ok = abap_true THEN '06' ELSE '05' ).
    ev_log    = lv_msg.
  ENDMETHOD.

  METHOD parse_xml.

    rs_dte-moneda = 'CLP'. " default

    " En ABAP Cloud se usa cl_abap_conv_codepage
    DATA(lv_xstr) = cl_abap_conv_codepage=>create_out( 
                          codepage = `UTF-8` 
                      )->convert( source = iv_xml ).

    DATA(lo_reader) = cl_sxml_string_reader=>create( lv_xstr ).

    " Path stack – last entry = current element name
    DATA lt_path     TYPE TABLE OF string WITH EMPTY KEY.
    DATA lv_in_ref   TYPE abap_bool.
    DATA lv_in_impto TYPE abap_bool.
    DATA lv_tipo_imp TYPE string.
    DATA ls_cur_ref  TYPE ty_referencia.
    DATA lt_refs     TYPE tt_referencias.

    TRY.
        DO.
          DATA(lo_node) = lo_reader->read_next_node( ).
          IF lo_node IS INITIAL. EXIT. ENDIF.

          CASE lo_node->type.

            WHEN if_sxml_node=>co_nt_element_open.
              DATA(lo_op) = CAST if_sxml_open_element( lo_node ).
              DATA(lv_nm) = lo_op->qname-name.
              APPEND lv_nm TO lt_path.
              CASE lv_nm.
                WHEN 'Referencia'. lv_in_ref   = abap_true. CLEAR ls_cur_ref.
                WHEN 'ImptoReten'. lv_in_impto = abap_true. CLEAR lv_tipo_imp.
              ENDCASE.

            WHEN if_sxml_node=>co_nt_element_close.
              DATA(lo_cl)  = CAST if_sxml_close_element( lo_node ).
              CASE lo_cl->qname-name.
                WHEN 'Referencia'. lv_in_ref   = abap_false. APPEND ls_cur_ref TO lt_refs.
                WHEN 'ImptoReten'. lv_in_impto = abap_false.
              ENDCASE.
              DATA(lv_pi) = lines( lt_path ).
              IF lv_pi > 0. DELETE lt_path INDEX lv_pi. ENDIF.

            WHEN if_sxml_node=>co_nt_value.
              DATA(lo_vn) = CAST if_sxml_value_node( lo_node ).
              DATA(lv_v)  = lo_vn->get_value( ).
              DATA(lv_pe) = lines( lt_path ).
              CHECK lv_pe > 0.
              DATA(lv_e) = lt_path[ lv_pe ].

              IF lv_in_ref = abap_true.
                CASE lv_e.
                  WHEN 'NroLinRef'. ls_cur_ref-nro_lin  = CONV i( lv_v ).
                  WHEN 'TpoDocRef'. ls_cur_ref-tipo_doc  = lv_v.
                  WHEN 'FolioRef'.  ls_cur_ref-folio_ref = lv_v.
                ENDCASE.
              ELSEIF lv_in_impto = abap_true.
                CASE lv_e.
                  WHEN 'TipoImp'. lv_tipo_imp = lv_v.
                  WHEN 'MontoImp'.
                    CASE lv_tipo_imp.
                      WHEN '14' OR '15'.   rs_dte-iva_retenido = lv_v.
                      WHEN '27' OR '271'.  rs_dte-iec          = lv_v.
                    ENDCASE.
                ENDCASE.
              ELSE.
                CASE lv_e.
                  WHEN 'TipoDTE'.  rs_dte-tipo_dte     = CONV numc3( lv_v ).
                  WHEN 'Folio'.    rs_dte-folio        = lv_v.
                  WHEN 'FchEmis'.
                    rs_dte-fecha_emision = CONV dats(
                      lv_v(4) && lv_v+5(2) && lv_v+8(2) ).
                  WHEN 'TpoMoneda'.
                    IF lv_v IS NOT INITIAL. rs_dte-moneda = lv_v. ENDIF.
                  WHEN 'RUTEmisor'. rs_dte-rut_emisor   = normalize_rut( lv_v ).
                  WHEN 'RznSoc'.    rs_dte-razon_social  = lv_v.
                  WHEN 'RUTRecep'.  rs_dte-rut_receptor  = normalize_rut( lv_v ).
                  WHEN 'MntNeto'.   rs_dte-monto_neto    = lv_v.
                  WHEN 'MntExe'.    rs_dte-monto_exento  = lv_v.
                  WHEN 'IVA'.       rs_dte-iva           = lv_v.
                  WHEN 'MntTotal'.  rs_dte-monto_total   = lv_v.
                ENDCASE.
              ENDIF.

          ENDCASE.
        ENDDO.
      CATCH cx_sxml_parse_error INTO DATA(lx_xml).
        RAISE EXCEPTION NEW cx_abap_invalid_value( value = lx_xml->get_text( ) ).
    ENDTRY.

    " Process references
    rs_dte-tiene_ref = abap_false.
    LOOP AT lt_refs INTO DATA(ls_ref).
      CASE ls_ref-tipo_doc.
        WHEN '801'.
          rs_dte-oc_ref    = CONV ebeln( ls_ref-folio_ref ).
          rs_dte-tiene_ref = abap_true.
        WHEN 'HES'.
          rs_dte-hes_ref   = CONV belnr_d( ls_ref-folio_ref ).
          rs_dte-tiene_ref = abap_true.
        WHEN '700' OR '701'.
          rs_dte-em_ref    = CONV belnr_d( ls_ref-folio_ref ).
          rs_dte-tiene_ref = abap_true.
        WHEN '33' OR '34'.
          rs_dte-folio_ref = ls_ref-folio_ref.
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.

  METHOD normalize_rut.
    rv_rut = iv_rut.
    REPLACE ALL OCCURRENCES OF '.' IN rv_rut WITH ''.
    rv_rut = condense( rv_rut ).
  ENDMETHOD.

  METHOD validate_referencia_xml.
    ev_ok = abap_false.

    " Verificar si el proveedor está configurado como servicios generales
    DATA(lv_es_serv_gen) = abap_false.
    SELECT SINGLE @abap_true
      FROM zdte_config
      WHERE parametro = @( |PROV_SERV_{ is_dte-rut_emisor }| )
      INTO @DATA(lv_prov_config).
    IF sy-subrc = 0.
      lv_es_serv_gen = abap_true.
    ENDIF.

    IF lv_es_serv_gen = abap_true.
      ev_ok      = abap_true.
      ev_mensaje = 'Proveedor de servicios generales: omite validación de referencia'.
      RETURN.
    ENDIF.

    IF is_dte-tipo_dte = 56 OR is_dte-tipo_dte = 55.
      IF is_dte-folio_ref IS INITIAL AND is_dte-oc_ref IS INITIAL.
        ev_ok      = abap_false.
        ev_mensaje = |DTE tipo { is_dte-tipo_dte } sin referencia a factura ni OC. Sujeto a rechazo.|.
        RETURN.
      ENDIF.
      ev_ok = abap_true.
      RETURN.
    ENDIF.

    IF is_dte-tiene_ref = abap_false OR
       ( is_dte-oc_ref IS INITIAL AND
         is_dte-hes_ref IS INITIAL AND
         is_dte-em_ref  IS INITIAL ).
      ev_ok      = abap_false.
      ev_mensaje = 'El DTE no contiene documentos de referencia (OC/HES/EM) en <Referencia>. Sujeto a rechazo.'.
      RETURN.
    ENDIF.

    ev_ok      = abap_true.
    ev_mensaje = ''.
  ENDMETHOD.

  METHOD validate_doc_sap.
    ev_ok = abap_false.

    " Validar OC → I_PurchaseOrderAPI01
    IF is_dte-oc_ref IS NOT INITIAL.
      SELECT SINGLE PurchaseOrder, CompanyCode
        FROM I_PurchaseOrderAPI01
        WHERE PurchaseOrder = @is_dte-oc_ref
        INTO @DATA(ls_po).

      IF sy-subrc <> 0.
        ev_ok      = abap_false.
        ev_mensaje = |OC { is_dte-oc_ref } no existe en SAP.|.
        RETURN.
      ENDIF.

      IF ls_po-CompanyCode <> iv_sociedad.
        ev_ok      = abap_false.
        ev_mensaje = |OC { is_dte-oc_ref } pertenece a la sociedad { ls_po-CompanyCode }, no a { iv_sociedad }.|.
        RETURN.
      ENDIF.
    ENDIF.

    " Validar HES → I_ServiceEntrySheet (solo existencia; campo de borrado varía por release)
    IF is_dte-hes_ref IS NOT INITIAL.
      SELECT SINGLE @abap_true
        FROM I_ServiceEntrySheetAPI01
        WHERE ServiceEntrySheet = @is_dte-hes_ref
        INTO @DATA(lv_ses_exists).

      IF sy-subrc <> 0.
        ev_ok      = abap_false.
        ev_mensaje = |HES { is_dte-hes_ref } no existe en SAP.|.
        RETURN.
      ENDIF.
    ENDIF.

    " Validar EM → I_MaterialDocumentHeader_2
    IF is_dte-em_ref IS NOT INITIAL.
      DATA(lv_gjahr_em) = CONV gjahr( sy-datum(4) ).
      SELECT SINGLE MaterialDocument
        FROM I_MaterialDocumentHeader_2
        WHERE MaterialDocument     = @is_dte-em_ref
          AND MaterialDocumentYear = @lv_gjahr_em
        INTO @DATA(lv_mblnr).

      IF sy-subrc <> 0.
        lv_gjahr_em = CONV gjahr( sy-datum(4) - 1 ).
        SELECT SINGLE MaterialDocument
          FROM I_MaterialDocumentHeader_2
          WHERE MaterialDocument     = @is_dte-em_ref
            AND MaterialDocumentYear = @lv_gjahr_em
          INTO @lv_mblnr.

        IF sy-subrc <> 0.
          ev_ok      = abap_false.
          ev_mensaje = |EM { is_dte-em_ref } no existe en SAP.|.
          RETURN.
        ENDIF.
      ENDIF.
    ENDIF.

    ev_ok      = abap_true.
    ev_mensaje = ''.
  ENDMETHOD.

  METHOD validate_hes_oc.
    ev_ok = abap_false.

    IF is_dte-oc_ref IS INITIAL.
      ev_ok = abap_true. RETURN.
    ENDIF.

    " Validar HES → OC via I_ServiceEntrySheet (tiene campo PurchaseOrder directo)
    IF is_dte-hes_ref IS NOT INITIAL.
      SELECT SINGLE @abap_true
        FROM I_ServiceEntrySheetAPI01
        WHERE ServiceEntrySheet = @is_dte-hes_ref
          AND PurchaseOrder     = @is_dte-oc_ref
        INTO @DATA(lv_hes_oc).

      IF sy-subrc <> 0 OR lv_hes_oc <> abap_true.
        ev_ok      = abap_false.
        ev_mensaje = |HES { is_dte-hes_ref } no corresponde a la OC { is_dte-oc_ref }.|.
        RETURN.
      ENDIF.
    ENDIF.

    " Validar EM → OC via I_MaterialDocumentItem_2
    IF is_dte-em_ref IS NOT INITIAL.
      SELECT SINGLE @abap_true
        FROM I_MaterialDocumentItem_2
        WHERE MaterialDocument = @is_dte-em_ref
          AND PurchaseOrder    = @is_dte-oc_ref
        INTO @DATA(lv_em_oc).

      IF sy-subrc <> 0 OR lv_em_oc <> abap_true.
        ev_ok      = abap_false.
        ev_mensaje = |EM { is_dte-em_ref } no corresponde a la OC { is_dte-oc_ref }.|.
        RETURN.
      ENDIF.
    ENDIF.

    ev_ok      = abap_true.
    ev_mensaje = ''.
  ENDMETHOD.

  METHOD validate_sociedad.
    ev_ok = abap_false.

    DATA(lv_rut_sociedad) = get_rut_sociedad( iv_sociedad ).

    IF lv_rut_sociedad IS INITIAL.
      ev_ok      = abap_false.
      ev_mensaje = |No se pudo determinar el RUT de la sociedad { iv_sociedad }. Configure TaxNumber2 en I_CompanyCode.|.
      RETURN.
    ENDIF.

    DATA(lv_rut_recep_norm) = normalize_rut( CONV string( is_dte-rut_receptor ) ).
    DATA(lv_rut_soc_norm)   = normalize_rut( lv_rut_sociedad ).

    IF lv_rut_recep_norm <> lv_rut_soc_norm.
      ev_ok      = abap_false.
      ev_mensaje = |RUT receptor del DTE ({ is_dte-rut_receptor }) no coincide con RUT sociedad { iv_sociedad } ({ lv_rut_sociedad }).|.
      RETURN.
    ENDIF.

    ev_ok      = abap_true.
    ev_mensaje = ''.
  ENDMETHOD.

  METHOD validate_proveedor.
    ev_ok = abap_false.

    DATA lv_lifnr_oc TYPE lifnr.

    IF is_dte-oc_ref IS NOT INITIAL.
      " OC directa → I_PurchaseOrderAPI01
      SELECT SINGLE Supplier
        FROM I_PurchaseOrderAPI01
        WHERE PurchaseOrder = @is_dte-oc_ref
        INTO @lv_lifnr_oc.

    ELSEIF is_dte-hes_ref IS NOT INITIAL.
      " HES → OC via I_ServiceEntrySheet → proveedor
      DATA lv_ebeln_hes TYPE ebeln.
      SELECT SINGLE PurchaseOrder
        FROM I_ServiceEntrySheetAPI01
        WHERE ServiceEntrySheet = @is_dte-hes_ref
        INTO @lv_ebeln_hes.
      IF sy-subrc = 0.
        SELECT SINGLE Supplier
          FROM I_PurchaseOrderAPI01
          WHERE PurchaseOrder = @lv_ebeln_hes
          INTO @lv_lifnr_oc.
      ENDIF.

    ELSEIF is_dte-em_ref IS NOT INITIAL.
      " EM → OC via I_MaterialDocumentItem_2 → proveedor
      DATA lv_ebeln_em TYPE ebeln.
      SELECT SINGLE PurchaseOrder
        FROM I_MaterialDocumentItem_2
        WHERE MaterialDocument = @is_dte-em_ref
        INTO @lv_ebeln_em.
      IF sy-subrc = 0.
        SELECT SINGLE Supplier
          FROM I_PurchaseOrderAPI01
          WHERE PurchaseOrder = @lv_ebeln_em
          INTO @lv_lifnr_oc.
      ENDIF.
    ENDIF.

    IF lv_lifnr_oc IS INITIAL.
      ev_ok      = abap_false.
      ev_mensaje = 'No se pudo determinar el proveedor del documento de referencia en SAP.'.
      RETURN.
    ENDIF.

    DATA(lv_rut_sap) = normalize_rut( get_rut_proveedor( lv_lifnr_oc ) ).
    DATA(lv_rut_dte) = normalize_rut( CONV string( is_dte-rut_emisor ) ).

    IF lv_rut_sap IS INITIAL.
      ev_ok      = abap_false.
      ev_mensaje = |Proveedor { lv_lifnr_oc } no tiene RUT (TaxNumber1) en I_Supplier.|.
      RETURN.
    ENDIF.

    IF lv_rut_sap <> lv_rut_dte.
      ev_ok      = abap_false.
      ev_mensaje = |RUT emisor DTE ({ is_dte-rut_emisor }) no coincide con proveedor { lv_lifnr_oc } ({ lv_rut_sap }).|.
      RETURN.
    ENDIF.

    ev_ok      = abap_true.
    ev_mensaje = ''.
  ENDMETHOD.

  METHOD validate_monto.
    ev_ok = abap_false.

    DATA(lv_tol_pct) = get_config( 'TOL_PORCENTAJE' ).
    DATA(lv_tol_clp) = get_config( 'TOL_MONTO_CLP'  ).
    IF lv_tol_pct = 0. lv_tol_pct = 5.     ENDIF.
    IF lv_tol_clp = 0. lv_tol_clp = 10000. ENDIF.

    DATA(lv_monto_pend) = get_monto_pendiente(
      is_dte      = is_dte
      iv_sociedad = iv_sociedad ).

    IF lv_monto_pend = 0.
      ev_ok      = abap_false.
      ev_mensaje = 'No existe saldo pendiente de facturar en el documento de referencia.'.
      RETURN.
    ENDIF.

    DATA lv_monto_dte_clp TYPE p LENGTH 15 DECIMALS 2.
    IF is_dte-moneda = 'CLP' OR is_dte-moneda IS INITIAL.
      lv_monto_dte_clp = is_dte-monto_total.
    ELSE.
      DATA(lv_tc) = get_tipo_cambio(
        iv_moneda = is_dte-moneda
        iv_fecha  = is_dte-fecha_emision ).
      lv_monto_dte_clp = is_dte-monto_total * lv_tc.
    ENDIF.

    DATA(lv_diferencia) = abs( lv_monto_dte_clp - lv_monto_pend ).

    DATA(lv_tol_por_pct) = lv_monto_pend * lv_tol_pct / 100.
    DATA lv_tol_aplicada TYPE p LENGTH 15 DECIMALS 2.
    IF lv_tol_por_pct < lv_tol_clp.
      lv_tol_aplicada = lv_tol_por_pct.
    ELSE.
      lv_tol_aplicada = lv_tol_clp.
    ENDIF.

    IF lv_diferencia > lv_tol_aplicada.
      ev_ok      = abap_false.
      ev_mensaje = |Monto DTE ({ lv_monto_dte_clp } CLP) difiere del saldo pendiente|
               && | ({ lv_monto_pend } CLP) en { lv_diferencia } CLP.|
               && | Tolerancia máxima: { lv_tol_aplicada } CLP.|
               && ' Si la EM es parcial, use "Indicar Posiciones".'.
      RETURN.
    ENDIF.

    ev_ok      = abap_true.
    ev_mensaje = ''.
  ENDMETHOD.

  METHOD contabilizar.
    ev_ok        = abap_false.
    ev_doc_fact  = ''.
    ev_year_fact = ''.
    ev_mensaje   = ''.

    " ---- Recopilar ítems en tabla local antes del EML ----
    TYPES: BEGIN OF ty_inv_item,
             cid          TYPE string,
             item_no      TYPE numc5,
             po_number    TYPE ebeln,
             po_item      TYPE ebelp,
             quantity     TYPE menge_d,
             unit         TYPE meins,
             sheet_no     TYPE belnr_d,
             item_amount  TYPE wrbtr,
             ref_doc      TYPE belnr_d,
             ref_doc_item TYPE numc4,
           END OF ty_inv_item.
    DATA lt_items TYPE TABLE OF ty_inv_item WITH EMPTY KEY.
    DATA lv_cnt   TYPE i VALUE 1.

    IF it_posiciones IS SUPPLIED AND it_posiciones IS NOT INITIAL.
      LOOP AT it_posiciones INTO DATA(ls_pos).
        APPEND VALUE #(
          cid      = |ITEM{ lv_cnt }|
          item_no  = CONV numc5( lv_cnt )
          po_number = is_dte-oc_ref
          po_item   = ls_pos-posicion
          quantity  = ls_pos-cantidad
          unit      = ls_pos-unidad
          sheet_no  = is_dte-hes_ref
        ) TO lt_items.
        lv_cnt += 1.
      ENDLOOP.

    ELSEIF is_dte-hes_ref IS NOT INITIAL.
      " HES: un único ítem de factura referenciando la hoja de servicio completa
      APPEND VALUE #(
        cid         = |ITEM{ lv_cnt }|
        item_no     = CONV numc5( lv_cnt )
        po_number   = is_dte-oc_ref
        sheet_no    = is_dte-hes_ref
        item_amount = CONV wrbtr( is_dte-monto_total )
      ) TO lt_items.
      lv_cnt += 1.

    ELSEIF is_dte-em_ref IS NOT INITIAL.
      " ítems desde I_MaterialDocumentItem_2 (MSEG)
      " TODO: verificar nombre exacto de campos Quantity/BaseUnit en el sistema
      SELECT MaterialDocument, MaterialDocumentItem, PurchaseOrder, PurchaseOrderItem,
             QuantityInBaseUnit, MaterialBaseUnit, TotalGoodsMvtAmtInCCCrcy
        FROM I_MaterialDocumentItem_2
        WHERE MaterialDocument = @is_dte-em_ref
          AND PurchaseOrder    = @is_dte-oc_ref
        INTO TABLE @DATA(lt_mseg).

      LOOP AT lt_mseg INTO DATA(ls_mseg).
        APPEND VALUE #(
          cid          = |ITEM{ lv_cnt }|
          item_no      = CONV numc5( lv_cnt )
          po_number    = ls_mseg-PurchaseOrder
          po_item      = ls_mseg-PurchaseOrderItem
          ref_doc      = ls_mseg-MaterialDocument
          ref_doc_item = CONV numc4( ls_mseg-MaterialDocumentItem )
          quantity     = ls_mseg-QuantityInBaseUnit
          unit         = ls_mseg-MaterialBaseUnit
          item_amount  = ls_mseg-TotalGoodsMvtAmtInCCCrcy
        ) TO lt_items.
        lv_cnt += 1.
      ENDLOOP.
    ENDIF.

    " ---- Tabla de impuestos ----
    TYPES: BEGIN OF ty_inv_tax,
             cid        TYPE string,
             tax_code   TYPE mwskz,
             tax_amount TYPE wrbtr,
             tax_base   TYPE wrbtr,
           END OF ty_inv_tax.
    DATA lt_taxes TYPE TABLE OF ty_inv_tax WITH EMPTY KEY.

    IF is_dte-iva > 0.
      APPEND VALUE #(
        cid        = 'TAX_IVA'
        tax_code   = 'V1'
        tax_amount = CONV wrbtr( is_dte-iva )
        tax_base   = CONV wrbtr( is_dte-monto_neto )
      ) TO lt_taxes.
    ENDIF.
    IF is_dte-iva_retenido > 0.
      APPEND VALUE #(
        cid        = 'TAX_IVA_RET'
        tax_code   = 'VR'
        tax_amount = CONV wrbtr( is_dte-iva_retenido )
        tax_base   = CONV wrbtr( is_dte-monto_neto )
      ) TO lt_taxes.
    ENDIF.

    " ---- EML: crear factura de proveedor via action Create de I_SupplierInvoiceTP ----
    DATA(lv_moneda) = COND waers( WHEN is_dte-moneda IS INITIAL THEN 'CLP'
                                  ELSE is_dte-moneda ).

    MODIFY ENTITIES OF I_SupplierInvoiceTP
      ENTITY SupplierInvoice
        EXECUTE Create
          FROM VALUE #( (
            %cid   = 'INV_HDR'
            %param = VALUE #(
              SupplierInvoiceIsCreditMemo   = COND #( WHEN is_dte-tipo_dte = '56'
                                                      THEN abap_true
                                                      ELSE abap_false )
              DocumentDate                  = is_dte-fecha_emision
              PostingDate                   = cl_abap_context_info=>get_system_date( )
              CompanyCode                   = iv_sociedad
              DocumentCurrency              = lv_moneda
              InvoiceGrossAmount            = CONV rmwwr( is_dte-monto_total )
              TaxIsCalculatedAutomatically  = abap_false
              SupplierInvoiceIDByInvcgParty = is_dte-folio

              _ItemsWithPOReference = VALUE #(
                FOR ls_ei IN lt_items
                ( SupplierInvoiceItem         = ls_ei-item_no
                  PurchaseOrder               = ls_ei-po_number
                  PurchaseOrderItem           = ls_ei-po_item
                  QuantityInPurchaseOrderUnit = ls_ei-quantity
                  PurchaseOrderQuantityUnit   = ls_ei-unit
                  ServiceEntrySheet           = ls_ei-sheet_no
                  SupplierInvoiceItemAmount   = ls_ei-item_amount
                  ReferenceDocument           = ls_ei-ref_doc
                  ReferenceDocumentItem       = CONV lfpos( ls_ei-ref_doc_item )
                  DocumentCurrency            = lv_moneda
                )
              )

              _Taxes = VALUE #(
                FOR ls_tx IN lt_taxes
                ( TaxCode               = ls_tx-tax_code
                  TaxAmountInDocCry     = ls_tx-tax_amount
                  TaxBaseAmountInDocCry = ls_tx-tax_base
                  DocumentCurrency      = lv_moneda
                )
              )
            )
          ) )
      MAPPED   DATA(ls_mapped)
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    " Verificar errores del MODIFY (IS NOT INITIAL es genérico, no requiere alias de entidad)
    IF ls_failed IS NOT INITIAL.
      ROLLBACK ENTITIES.
      ev_ok      = abap_false.
      ev_mensaje = 'Error al crear factura de proveedor. Verificar log de aplicación (SLG1).'.
      RETURN.
    ENDIF.

    " Confirmar
    COMMIT ENTITIES.

    " Obtener número del documento desde el resultado del COMMIT ENTITIES
    DATA(ls_created_key) = VALUE #( ls_mapped-SupplierInvoice[ %cid = 'INV_HDR' ] OPTIONAL ).
    IF ls_created_key-SupplierInvoice IS NOT INITIAL.
      ev_doc_fact  = CONV belnr_d( ls_created_key-SupplierInvoice ).
      ev_year_fact = CONV gjahr( ls_created_key-SupplierInvoiceFiscalYear ).
    ENDIF.

    ev_ok      = abap_true.
    ev_mensaje = |DTE contabilizado: documento { ev_doc_fact } / { ev_year_fact }.|.
  ENDMETHOD.

  METHOD get_rut_sociedad.
"    SELECT SINGLE TaxNumber2
 "      FROM I_CompanyCode
 "     WHERE CompanyCode = @iv_sociedad
 "     INTO @rv_rut.
  ENDMETHOD.

  METHOD get_rut_proveedor.
    SELECT SINGLE TaxNumber1
      FROM I_Supplier
      WHERE Supplier = @iv_lifnr
      INTO @rv_rut.
  ENDMETHOD.

  METHOD get_monto_pendiente.

    IF is_dte-hes_ref IS NOT INITIAL.
      " Monto total de la HES desde I_ServiceEntrySheet
      " TODO: verificar campo de importe en I_ServiceEntrySheet del sistema
      DATA lv_monto_hes TYPE wrbtr.
      SELECT SUM( NetAmount )
        FROM I_ServiceEntrySheetItemAPI01
        WHERE ServiceEntrySheet = @is_dte-hes_ref
        INTO @lv_monto_hes.

      " Facturas ya contabilizadas contra esta HES → I_SupplierInvoiceItem
      DATA lv_facturado TYPE p LENGTH 15 DECIMALS 2.
      SELECT SUM( SupplierInvoiceItemAmount )
        FROM I_SuplrInvcItemPurOrdRefAPI01
        WHERE ReferenceDocument = @is_dte-hes_ref
        INTO @lv_facturado.

      rv_monto_clp = lv_monto_hes - lv_facturado.

    ELSEIF is_dte-em_ref IS NOT INITIAL.
      " Valor total de la EM desde I_MaterialDocumentItem_2
      DATA lv_monto_em TYPE p LENGTH 15 DECIMALS 2.
      SELECT SUM( TotalGoodsMvtAmtInCCCrcy )
        FROM I_MaterialDocumentItem_2
        WHERE MaterialDocument = @is_dte-em_ref
          AND PurchaseOrder    = @is_dte-oc_ref
        INTO @lv_monto_em.

      " Facturas ya contabilizadas contra la OC → I_SupplierInvoiceItem
      SELECT SUM( SupplierInvoiceItemAmount )
        FROM I_SuplrInvcItemPurOrdRefAPI01
        WHERE PurchaseOrder = @is_dte-oc_ref
        INTO @lv_facturado.

      rv_monto_clp = lv_monto_em - lv_facturado.

    ELSEIF is_dte-oc_ref IS NOT INITIAL.
      " Valor neto OC desde I_PurchaseOrderItemAPI01
      " TODO: verificar nombre exacto del campo NETWR en el sistema (NetPriceAmount / ItemNetAmount)
      DATA lv_netwr_oc TYPE p LENGTH 15 DECIMALS 2.
      SELECT SUM( NetPriceAmount )
        FROM I_PurchaseOrderItemAPI01
        WHERE PurchaseOrder = @is_dte-oc_ref
        INTO @lv_netwr_oc.

      SELECT SUM( SupplierInvoiceItemAmount )
        FROM I_SuplrInvcItemPurOrdRefAPI01
        WHERE PurchaseOrder = @is_dte-oc_ref
        INTO @lv_facturado.

      rv_monto_clp = lv_netwr_oc - lv_facturado.
    ENDIF.

    " Convertir a CLP si corresponde
    IF is_dte-moneda <> 'CLP' AND is_dte-moneda IS NOT INITIAL.
      DATA(lv_tc) = get_tipo_cambio(
        iv_moneda = is_dte-moneda
        iv_fecha  = is_dte-fecha_emision ).
      rv_monto_clp = rv_monto_clp * lv_tc.
    ENDIF.

  ENDMETHOD.

  METHOD get_tipo_cambio.
    rv_tc = 1.

    IF iv_moneda = 'CLP' OR iv_moneda IS INITIAL.
      RETURN.
    ENDIF.

    DATA lv_one TYPE p LENGTH 15 DECIMALS 2 VALUE '1'.

    SELECT SINGLE
      CURRENCY_CONVERSION(
        amount             = @lv_one,
        source_currency    = @iv_moneda,
        target_currency    = @( CONV waers( 'CLP' ) ),
        exchange_rate_date = @iv_fecha,
        exchange_rate_type = 'M'
      ) AS tc
      FROM I_Currency
      WHERE Currency = @iv_moneda
      INTO @DATA(lv_converted).

    rv_tc = CONV wrbtr( lv_converted ).

    IF rv_tc = 0.
      rv_tc = 1.
    ENDIF.
  ENDMETHOD.

  METHOD get_config.
    SELECT SINGLE valor_num
      FROM zdte_config
      WHERE parametro = @iv_parametro
      INTO @rv_valor.
    IF sy-subrc <> 0.
      rv_valor = 0.
    ENDIF.
  ENDMETHOD.

ENDCLASS.