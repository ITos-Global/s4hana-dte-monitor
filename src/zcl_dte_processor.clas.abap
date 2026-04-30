CLASS zcl_dte_processor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " Tipos de DTE permitidos según especificación funcional
    CONSTANTS:
      BEGIN OF gc_tipo_dte_permitido,
        factura_afecta TYPE numc3 VALUE '033',
        factura_exenta TYPE numc3 VALUE '034',
        factura_compra TYPE numc3 VALUE '046',
        nota_debito    TYPE numc3 VALUE '056',
        nota_credito   TYPE numc3 VALUE '061',
      END OF gc_tipo_dte_permitido.

    CLASS-METHODS is_tipo_dte_permitido
      IMPORTING iv_tipo_dte    TYPE numc3
      RETURNING VALUE(rv_ok)   TYPE abap_bool.

    " Estructura pública con campos clave extraídos del XML del DTE.
    " Usada por el ingestor para crear el registro inicial en la tabla.
    TYPES: BEGIN OF ty_dte_meta,
             tipo_dte      TYPE numc3,
             folio         TYPE char20,
             rut_emisor    TYPE char12,
             rut_receptor  TYPE char12,
             fecha_emision TYPE dats,
             moneda        TYPE waers,
             monto_neto    TYPE p LENGTH 15 DECIMALS 2,
             monto_exento  TYPE p LENGTH 15 DECIMALS 2,
             iva           TYPE p LENGTH 15 DECIMALS 2,
             iec           TYPE p LENGTH 15 DECIMALS 2,
             iva_retenido  TYPE p LENGTH 15 DECIMALS 2,
             monto_total   TYPE p LENGTH 15 DECIMALS 2,
           END OF ty_dte_meta.

    METHODS extract_keys
      IMPORTING iv_xml         TYPE string
      RETURNING VALUE(rs_meta) TYPE ty_dte_meta
      RAISING   cx_abap_invalid_value.

    TYPES: BEGIN OF ty_posicion,
             posicion TYPE ebelp,
             material TYPE matnr,
             cantidad TYPE menge_d,
             unidad   TYPE meins,
           END OF ty_posicion.
    TYPES tt_posiciones TYPE STANDARD TABLE OF ty_posicion WITH DEFAULT KEY.

    " Resultado por posición para GetMontosPendientes (function bound).
    TYPES: BEGIN OF ty_pos_pendiente,
             purchase_order           TYPE ebeln,
             purchase_order_item      TYPE ebelp,
             service_entry_sheet      TYPE char10,
             service_entry_sheet_item TYPE numc5,
             purchase_order_amount    TYPE p LENGTH 13 DECIMALS 2,
             document_currency        TYPE waers,
           END OF ty_pos_pendiente.
    TYPES tt_pos_pendiente TYPE STANDARD TABLE OF ty_pos_pendiente WITH DEFAULT KEY.

    " Lectura del monto pendiente por posición HES desde I_PurchaseOrderHistoryAPI01.
    " No se admite parcialidad de facturación de la HES, por lo que se devuelven
    " las posiciones HES tal cual sin descontar facturas previas.
    " TODO: descontar HES ya facturadas y validar anulación cuando se implemente
    "       la verificación de I_SupplierInvoice.IsReversed.
    METHODS get_pendiente_hes
      IMPORTING iv_oc           TYPE ebeln
                iv_hes          TYPE char10
      RETURNING VALUE(rt_pos)   TYPE tt_pos_pendiente.

    METHODS process_dte
      IMPORTING
        iv_tipo_dte    TYPE zdte_monitor-tipo_dte
        iv_folio       TYPE zdte_monitor-folio
        iv_proveedor   TYPE zdte_monitor-proveedor
        iv_sociedad    TYPE zdte_monitor-sociedad   " RUT receptor
        iv_xml_data    TYPE string
      EXPORTING
        ev_estado      TYPE zdte_monitor-estado
        ev_log         TYPE string
        ev_bukrs       TYPE zdte_monitor-bukrs_sap
        ev_prov_sap    TYPE zdte_monitor-prov_sap
        ev_year_em     TYPE zdte_monitor-year_em
        ev_doc_fact    TYPE zdte_monitor-doc_fact
        ev_year_fact   TYPE zdte_monitor-year_fact.

    METHODS process_dte_with_positions
      IMPORTING
        iv_tipo_dte    TYPE zdte_monitor-tipo_dte
        iv_folio       TYPE zdte_monitor-folio
        iv_proveedor   TYPE zdte_monitor-proveedor
        iv_sociedad    TYPE zdte_monitor-sociedad   " RUT receptor
        iv_xml_data    TYPE string
        it_posiciones  TYPE tt_posiciones
      EXPORTING
        ev_estado      TYPE zdte_monitor-estado
        ev_log         TYPE string
        ev_bukrs       TYPE zdte_monitor-bukrs_sap
        ev_prov_sap    TYPE zdte_monitor-prov_sap
        ev_year_em     TYPE zdte_monitor-year_em
        ev_doc_fact    TYPE zdte_monitor-doc_fact
        ev_year_fact   TYPE zdte_monitor-year_fact.

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
      IMPORTING is_dte         TYPE ty_dte_xml
                iv_supplier    TYPE lifnr
      EXPORTING ev_ok          TYPE abap_bool
                ev_mensaje     TYPE string.

    METHODS validate_oc
      IMPORTING is_dte         TYPE ty_dte_xml
                iv_bukrs       TYPE bukrs
                iv_supplier    TYPE lifnr
      EXPORTING ev_ok          TYPE abap_bool
                ev_mensaje     TYPE string.

    METHODS validate_em
      IMPORTING is_dte         TYPE ty_dte_xml
      EXPORTING ev_ok          TYPE abap_bool
                ev_mensaje     TYPE string
                ev_year_em     TYPE gjahr.

    METHODS validate_hes
      IMPORTING is_dte         TYPE ty_dte_xml
      EXPORTING ev_ok          TYPE abap_bool
                ev_mensaje     TYPE string.

    METHODS validate_sociedad
      IMPORTING iv_rut_sociedad TYPE zdte_monitor-sociedad
      EXPORTING ev_ok           TYPE abap_bool
                ev_mensaje      TYPE string
                ev_bukrs        TYPE bukrs.

    METHODS validate_proveedor
      IMPORTING iv_rut_proveedor TYPE zdte_monitor-proveedor
      EXPORTING ev_ok            TYPE abap_bool
                ev_mensaje       TYPE string
                ev_supplier      TYPE lifnr.

    METHODS is_servicios_generales
      IMPORTING iv_supplier   TYPE lifnr
      RETURNING VALUE(rv_ok)  TYPE abap_bool.

    METHODS validate_monto
      IMPORTING is_dte      TYPE ty_dte_xml
                iv_bukrs    TYPE bukrs
      EXPORTING ev_ok       TYPE abap_bool
                ev_mensaje  TYPE string.

    METHODS contabilizar
      IMPORTING is_dte        TYPE ty_dte_xml
                iv_bukrs      TYPE bukrs
                it_posiciones TYPE tt_posiciones OPTIONAL
      EXPORTING ev_doc_fact   TYPE belnr_d
                ev_year_fact  TYPE gjahr
                ev_ok         TYPE abap_bool
                ev_mensaje    TYPE string.

    METHODS get_rut_proveedor
      IMPORTING iv_lifnr       TYPE lifnr
      RETURNING VALUE(rv_rut)  TYPE string.

    METHODS get_monto_pendiente
      IMPORTING is_dte              TYPE ty_dte_xml
                iv_bukrs            TYPE bukrs
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
    ev_bukrs     = ''.
    ev_prov_sap  = ''.
    ev_year_em   = ''.
    ev_doc_fact  = ''.
    ev_year_fact = ''.

    " 0) Tipo DTE permitido
    IF is_tipo_dte_permitido( iv_tipo_dte ) = abap_false.
      ev_estado = '04'.
      ev_log    = |Tipo de DTE { iv_tipo_dte } no permitido. Tipos válidos: 33, 34, 46, 56, 61.|.
      RETURN.
    ENDIF.

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

    " 1) Sociedad: RUT receptor → CompanyCode
    validate_sociedad(
      EXPORTING iv_rut_sociedad = iv_sociedad
      IMPORTING ev_ok           = lv_ok
                ev_mensaje      = lv_msg
                ev_bukrs        = ev_bukrs ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    " 2) Proveedor: RUT → Supplier
    validate_proveedor(
      EXPORTING iv_rut_proveedor = iv_proveedor
      IMPORTING ev_ok            = lv_ok
                ev_mensaje       = lv_msg
                ev_supplier      = ev_prov_sap ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    " 3) Existencia de docs de referencia (con fallback servicios generales)
    validate_referencia_xml(
      EXPORTING is_dte      = ls_dte
                iv_supplier = ev_prov_sap
      IMPORTING ev_ok       = lv_ok
                ev_mensaje  = lv_msg ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    " 4) Validación OC (existe / sociedad / proveedor / autorizada)
    validate_oc(
      EXPORTING is_dte      = ls_dte
                iv_bukrs    = ev_bukrs
                iv_supplier = ev_prov_sap
      IMPORTING ev_ok       = lv_ok
                ev_mensaje  = lv_msg ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    " 5) Validación EM (existe + asociada a OC); captura YEAR_EM
    validate_em(
      EXPORTING is_dte     = ls_dte
      IMPORTING ev_ok      = lv_ok
                ev_mensaje = lv_msg
                ev_year_em = ev_year_em ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    " 6) Validación HES (existe + asociada a OC + aprobada)
    validate_hes(
      EXPORTING is_dte     = ls_dte
      IMPORTING ev_ok      = lv_ok
                ev_mensaje = lv_msg ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    " 7) Validación de monto (saldo pendiente vs. tolerancia)
    validate_monto(
      EXPORTING is_dte    = ls_dte
                iv_bukrs  = ev_bukrs
      IMPORTING ev_ok     = lv_ok
                ev_mensaje = lv_msg ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    " 8) Contabilización
    contabilizar(
      EXPORTING is_dte       = ls_dte
                iv_bukrs     = ev_bukrs
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
    ev_bukrs     = ''.
    ev_prov_sap  = ''.
    ev_year_em   = ''.
    ev_doc_fact  = ''.
    ev_year_fact = ''.

    IF is_tipo_dte_permitido( iv_tipo_dte ) = abap_false.
      ev_estado = '04'.
      ev_log    = |Tipo de DTE { iv_tipo_dte } no permitido. Tipos válidos: 33, 34, 46, 56, 61.|.
      RETURN.
    ENDIF.

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

    validate_sociedad( EXPORTING iv_rut_sociedad  = iv_sociedad
                       IMPORTING ev_ok = lv_ok ev_mensaje = lv_msg ev_bukrs = ev_bukrs ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    validate_proveedor( EXPORTING iv_rut_proveedor = iv_proveedor
                        IMPORTING ev_ok = lv_ok ev_mensaje = lv_msg ev_supplier = ev_prov_sap ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    validate_referencia_xml( EXPORTING is_dte = ls_dte iv_supplier = ev_prov_sap
                             IMPORTING ev_ok = lv_ok ev_mensaje = lv_msg ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    validate_oc( EXPORTING is_dte = ls_dte iv_bukrs = ev_bukrs iv_supplier = ev_prov_sap
                 IMPORTING ev_ok = lv_ok ev_mensaje = lv_msg ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    validate_em( EXPORTING is_dte = ls_dte
                 IMPORTING ev_ok = lv_ok ev_mensaje = lv_msg ev_year_em = ev_year_em ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    validate_hes( EXPORTING is_dte = ls_dte
                  IMPORTING ev_ok = lv_ok ev_mensaje = lv_msg ).
    IF lv_ok = abap_false. ev_estado = '04'. ev_log = lv_msg. RETURN. ENDIF.

    contabilizar(
      EXPORTING is_dte        = ls_dte
                iv_bukrs      = ev_bukrs
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

  METHOD extract_keys.
    " Reutiliza parse_xml y mapea a la estructura pública de meta.
    DATA(ls_dte) = parse_xml( iv_xml ).
    rs_meta = VALUE #(
      tipo_dte      = ls_dte-tipo_dte
      folio         = ls_dte-folio
      rut_emisor    = ls_dte-rut_emisor
      rut_receptor  = ls_dte-rut_receptor
      fecha_emision = ls_dte-fecha_emision
      moneda        = ls_dte-moneda
      monto_neto    = ls_dte-monto_neto
      monto_exento  = ls_dte-monto_exento
      iva           = ls_dte-iva
      iec           = ls_dte-iec
      iva_retenido  = ls_dte-iva_retenido
      monto_total   = ls_dte-monto_total ).
  ENDMETHOD.

  METHOD is_tipo_dte_permitido.
    rv_ok = xsdbool(
      iv_tipo_dte = gc_tipo_dte_permitido-factura_afecta OR
      iv_tipo_dte = gc_tipo_dte_permitido-factura_exenta OR
      iv_tipo_dte = gc_tipo_dte_permitido-factura_compra OR
      iv_tipo_dte = gc_tipo_dte_permitido-nota_debito    OR
      iv_tipo_dte = gc_tipo_dte_permitido-nota_credito ).
  ENDMETHOD.

  METHOD validate_sociedad.
    " Resuelve RUT receptor (iv_rut_sociedad) → CompanyCode SAP via I_AddlCompanyCodeInformation
    ev_ok    = abap_false.
    ev_bukrs = ''.

    SELECT SINGLE CompanyCode
      FROM I_AddlCompanyCodeInformation
      WHERE CompanyCodeParameterType  = 'TAXNR'
        AND CompanyCodeParameterValue = @iv_rut_sociedad
      INTO @ev_bukrs.

    IF sy-subrc <> 0.
      ev_mensaje = 'Sociedad del DTE no existe en SAP'.
      RETURN.
    ENDIF.

    ev_ok      = abap_true.
    ev_mensaje = ''.
  ENDMETHOD.

  METHOD validate_proveedor.
    " Resuelve RUT proveedor → Supplier SAP via I_Supplier (TaxNumber1)
    ev_ok       = abap_false.
    ev_supplier = ''.

    SELECT SINGLE Supplier
      FROM I_Supplier
      WHERE TaxNumber1 = @iv_rut_proveedor
      INTO @ev_supplier.

    IF sy-subrc <> 0.
      ev_mensaje = 'Proveedor del DTE no existe en SAP'.
      RETURN.
    ENDIF.

    ev_ok      = abap_true.
    ev_mensaje = ''.
  ENDMETHOD.

  METHOD is_servicios_generales.
    " Verifica si el proveedor está marcado con la característica PROV_IMPUTACION
    " en la clasificación de proveedores (ClassType 010, ClfnObjectTable LFA1).
    rv_ok = abap_false.

    SELECT SINGLE CharcInternalID
      FROM I_ClfnCharacteristic
      WHERE Characteristic = 'PROV_IMPUTACION'
      INTO @DATA(lv_charc_id).

    IF sy-subrc <> 0 OR lv_charc_id IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE @abap_true
      FROM I_ClfnObjectCharcValue
      WHERE ClfnObjectID    = @iv_supplier
        AND ClfnObjectTable = 'LFA1'
        AND CharcInternalID = @lv_charc_id
        AND ClassType       = '010'
      INTO @DATA(lv_match).

    rv_ok = COND #( WHEN sy-subrc = 0 THEN abap_true ELSE abap_false ).
  ENDMETHOD.

  METHOD validate_referencia_xml.
    " Lógica del spec:
    "  - Si OC ∧ (HES ∨ EM): ok
    "  - Si faltan, evaluar si proveedor es de servicios generales → ok
    "  - Caso contrario, rechazar con mensaje específico.
    ev_ok = abap_false.

    DATA(lv_oc_ok)  = xsdbool( is_dte-oc_ref  IS NOT INITIAL ).
    DATA(lv_hes_ok) = xsdbool( is_dte-hes_ref IS NOT INITIAL ).
    DATA(lv_em_ok)  = xsdbool( is_dte-em_ref  IS NOT INITIAL ).

    IF lv_oc_ok = abap_true AND ( lv_hes_ok = abap_true OR lv_em_ok = abap_true ).
      ev_ok      = abap_true.
      ev_mensaje = ''.
      RETURN.
    ENDIF.

    " Faltan referencias: ¿es proveedor de servicios generales?
    IF is_servicios_generales( iv_supplier ) = abap_true.
      ev_ok      = abap_true.
      ev_mensaje = 'Proveedor de servicios generales: omite validación de referencia.'.
      RETURN.
    ENDIF.

    " Mensajes específicos según qué falta
    IF lv_oc_ok = abap_false AND lv_hes_ok = abap_false AND lv_em_ok = abap_false.
      ev_mensaje = 'XML no tiene los documentos de referencia OC y HES/EM'.
    ELSEIF lv_oc_ok = abap_false.
      ev_mensaje = 'XML no tiene la referencia de la OC'.
    ELSE.
      ev_mensaje = 'XML no tiene la referencia de la HES o EM'.
    ENDIF.
  ENDMETHOD.

  METHOD validate_oc.
    " 4 checks: existe / sociedad / proveedor / autorizada (status 05)
    ev_ok = abap_false.

    IF is_dte-oc_ref IS INITIAL.
      ev_ok      = abap_true.
      ev_mensaje = ''.
      RETURN.
    ENDIF.

    " 1) Existe
    SELECT SINGLE @abap_true
      FROM I_PurchaseOrderAPI01
      WHERE PurchaseOrder = @is_dte-oc_ref
      INTO @DATA(lv_existe).
    IF sy-subrc <> 0.
      ev_mensaje = 'OC referencia no existe en SAP'.
      RETURN.
    ENDIF.

    " 2) Asociada a la sociedad del DTE
    SELECT SINGLE @abap_true
      FROM I_PurchaseOrderAPI01
      WHERE PurchaseOrder = @is_dte-oc_ref
        AND CompanyCode   = @iv_bukrs
      INTO @DATA(lv_soc).
    IF sy-subrc <> 0.
      ev_mensaje = 'OC referencia no corresponde la sociedad del DTE'.
      RETURN.
    ENDIF.

    " 3) Asociada al proveedor del DTE
    SELECT SINGLE @abap_true
      FROM I_PurchaseOrderAPI01
      WHERE PurchaseOrder = @is_dte-oc_ref
        AND Supplier      = @iv_supplier
      INTO @DATA(lv_prov).
    IF sy-subrc <> 0.
      ev_mensaje = 'OC referencia no corresponde al proveedor del DTE'.
      RETURN.
    ENDIF.

    " 4) Autorizada (PurchasingProcessingStatus = 05)
    SELECT SINGLE @abap_true
      FROM I_PurchaseOrderAPI01
      WHERE PurchaseOrder              = @is_dte-oc_ref
        AND PurchasingProcessingStatus = '05'
      INTO @DATA(lv_aprob).
    IF sy-subrc <> 0.
      ev_mensaje = 'OC referencia no se encuentra autorizada'.
      RETURN.
    ENDIF.

    ev_ok      = abap_true.
    ev_mensaje = ''.
  ENDMETHOD.

  METHOD validate_em.
    " Existencia + asociación a OC vía I_PurchaseOrderHistoryAPI01; captura YEAR_EM
    ev_ok      = abap_false.
    ev_year_em = ''.

    IF is_dte-em_ref IS INITIAL.
      ev_ok      = abap_true.
      ev_mensaje = ''.
      RETURN.
    ENDIF.

    " 1) Existencia (I_MaterialDocumentHeader_2 es la variante C1-released)
    SELECT SINGLE @abap_true
      FROM I_MaterialDocumentHeader_2
      WHERE MaterialDocument = @is_dte-em_ref
      INTO @DATA(lv_existe).
    IF sy-subrc <> 0.
      ev_mensaje = 'EM referencia no existe en SAP'.
      RETURN.
    ENDIF.

    " 2) Asociación a OC + captura del año
    SELECT SINGLE PurchasingHistoryDocumentYear
      FROM I_PurchaseOrderHistoryAPI01
      WHERE PurchaseOrder                 = @is_dte-oc_ref
        AND PurchasingHistoryDocumentType = '1'
        AND PurchasingHistoryCategory     = 'E'
        AND PurchasingHistoryDocument     = @is_dte-em_ref
      INTO @ev_year_em.
    IF sy-subrc <> 0.
      ev_mensaje = 'EM de referencia no corresponde a la OC indicada en el DTE'.
      CLEAR ev_year_em.
      RETURN.
    ENDIF.

    ev_ok      = abap_true.
    ev_mensaje = ''.
  ENDMETHOD.

  METHOD validate_hes.
    " Existencia + asociación a OC + aprobada (ApprovalStatus = 30)
    ev_ok = abap_false.

    IF is_dte-hes_ref IS INITIAL.
      ev_ok      = abap_true.
      ev_mensaje = ''.
      RETURN.
    ENDIF.

    " 1) Existencia
    SELECT SINGLE @abap_true
      FROM I_ServiceEntrySheetAPI01
      WHERE ServiceEntrySheet = @is_dte-hes_ref
      INTO @DATA(lv_existe).
    IF sy-subrc <> 0.
      ev_mensaje = 'HES referencia no existe en SAP'.
      RETURN.
    ENDIF.

    " 2) Asociación a la OC
    SELECT SINGLE @abap_true
      FROM I_ServiceEntrySheetAPI01
      WHERE ServiceEntrySheet = @is_dte-hes_ref
        AND PurchaseOrder     = @is_dte-oc_ref
      INTO @DATA(lv_oc).
    IF sy-subrc <> 0.
      ev_mensaje = 'HES referencia no corresponde a la OC de referencia'.
      RETURN.
    ENDIF.

    " 3) Aprobada (ApprovalStatus = 30)
    SELECT SINGLE @abap_true
      FROM I_ServiceEntrySheetAPI01
      WHERE ServiceEntrySheet = @is_dte-hes_ref
        AND ApprovalStatus    = '30'
      INTO @DATA(lv_aprob).
    IF sy-subrc <> 0.
      ev_mensaje = 'HES referencia no se encuentra aprobada'.
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
      is_dte    = is_dte
      iv_bukrs  = iv_bukrs ).

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
              CompanyCode                   = iv_bukrs
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

  METHOD get_rut_proveedor.
    SELECT SINGLE TaxNumber1
      FROM I_Supplier
      WHERE Supplier = @iv_lifnr
      INTO @rv_rut.
  ENDMETHOD.

  METHOD get_pendiente_hes.
    " Paso A del spec: posiciones HES en historial de OC.
    " HES no permite parcialidades → cada posición se devuelve completa.
    " La verificación de factura ya registrada/anulada queda como TODO.
    IF iv_oc IS INITIAL OR iv_hes IS INITIAL.
      RETURN.
    ENDIF.

    SELECT PurchaseOrder,
           PurchaseOrderItem,
           PurchasingHistoryDocument,
           PurchasingHistoryDocumentItem,
           PurchaseOrderAmount,
           DocumentCurrency
      FROM I_PurchaseOrderHistoryAPI01
      WHERE PurchaseOrder              = @iv_oc
        AND PurchasingHistoryDocumentType = 'S'
        AND PurchasingHistoryCategory     = '0'
        AND PurchasingHistoryDocument     = @iv_hes
      INTO TABLE @DATA(lt_hes_hist).

    LOOP AT lt_hes_hist INTO DATA(ls_h).
      APPEND VALUE #(
        purchase_order           = ls_h-PurchaseOrder
        purchase_order_item      = ls_h-PurchaseOrderItem
        service_entry_sheet      = ls_h-PurchasingHistoryDocument
        service_entry_sheet_item = ls_h-PurchasingHistoryDocumentItem
        purchase_order_amount    = ls_h-PurchaseOrderAmount
        document_currency        = ls_h-DocumentCurrency
      ) TO rt_pos.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_monto_pendiente.

    DATA lv_facturado TYPE p LENGTH 15 DECIMALS 2.

    IF is_dte-hes_ref IS NOT INITIAL.
      " Lectura por posición HES (sin parcialidad).
      DATA(lt_pos_hes) = get_pendiente_hes(
        iv_oc  = is_dte-oc_ref
        iv_hes = is_dte-hes_ref ).

      DATA lv_monto_hes_doc TYPE p LENGTH 15 DECIMALS 2.
      DATA lv_moneda_hes    TYPE waers.
      LOOP AT lt_pos_hes INTO DATA(ls_pos_hes).
        lv_monto_hes_doc = lv_monto_hes_doc + ls_pos_hes-purchase_order_amount.
        IF lv_moneda_hes IS INITIAL.
          lv_moneda_hes = ls_pos_hes-document_currency.
        ENDIF.
      ENDLOOP.

      " Convertir a CLP usando la moneda de la HES (no la del DTE).
      IF lv_moneda_hes IS INITIAL OR lv_moneda_hes = 'CLP'.
        rv_monto_clp = lv_monto_hes_doc.
      ELSE.
        DATA(lv_tc_hes) = get_tipo_cambio(
          iv_moneda = lv_moneda_hes
          iv_fecha  = is_dte-fecha_emision ).
        rv_monto_clp = lv_monto_hes_doc * lv_tc_hes.
      ENDIF.
      RETURN.

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