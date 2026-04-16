CLASS zcl_dte_processor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_posicion,
             posicion TYPE ekpo-ebelp,
             material TYPE ekpo-matnr,
             cantidad TYPE ekpo-menge,
             unidad   TYPE ekpo-meins,
           END OF ty_posicion.
    TYPES tt_posiciones TYPE STANDARD TABLE OF ty_posicion WITH DEFAULT KEY.

    " Proceso principal DTE
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

    " Proceso con posiciones explícitas (EM parciales)
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

    " Estructura interna con todos los datos extraídos del XML DTE
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

    " Estructura de referencia del XML (sección <Referencia>)
    TYPES: BEGIN OF ty_referencia,
             nro_lin    TYPE i,
             tipo_doc   TYPE char10,   " 801=OC, HES, EM, 33/34/56/55 para NC/ND
             folio_ref  TYPE char20,
           END OF ty_referencia.
    TYPES tt_referencias TYPE STANDARD TABLE OF ty_referencia WITH DEFAULT KEY.

    " Parsear XML DTE usando cl_ixml
    METHODS parse_xml
      IMPORTING iv_xml        TYPE string
      RETURNING VALUE(rs_dte) TYPE ty_dte_xml
      RAISING   cx_dynamic_check.

    " Extraer texto de un nodo XML por nombre de elemento
    METHODS get_xml_value
      IMPORTING io_parent  TYPE REF TO if_ixml_node
                iv_element TYPE string
      RETURNING VALUE(rv_value) TYPE string.

    " Extraer todas las referencias del XML
    METHODS get_xml_referencias
      IMPORTING io_doc          TYPE REF TO if_ixml_document
      RETURNING VALUE(rt_refs) TYPE tt_referencias.

    " Normalizar RUT chileno: eliminar puntos, dejar guión
    METHODS normalize_rut
      IMPORTING iv_rut        TYPE string
      RETURNING VALUE(rv_rut) TYPE string.

    " REGLA 1: Documento de referencia presente en XML
    METHODS validate_referencia_xml
      IMPORTING is_dte      TYPE ty_dte_xml
      EXPORTING ev_ok       TYPE abap_bool
                ev_mensaje  TYPE string.

    " REGLA 2: OC / HES / EM existen y vigentes en SAP
    METHODS validate_doc_sap
      IMPORTING is_dte      TYPE ty_dte_xml
                iv_sociedad TYPE bukrs
      EXPORTING ev_ok       TYPE abap_bool
                ev_mensaje  TYPE string.

    " REGLA 3: HES/EM corresponde a la OC indicada
    METHODS validate_hes_oc
      IMPORTING is_dte      TYPE ty_dte_xml
      EXPORTING ev_ok       TYPE abap_bool
                ev_mensaje  TYPE string.

    " REGLA 4: Sociedad receptora del DTE = sociedad SAP
    METHODS validate_sociedad
      IMPORTING is_dte      TYPE ty_dte_xml
                iv_sociedad TYPE bukrs
      EXPORTING ev_ok       TYPE abap_bool
                ev_mensaje  TYPE string.

    " REGLA 5: Proveedor del DTE = proveedor en doc. de referencia SAP
    METHODS validate_proveedor
      IMPORTING is_dte      TYPE ty_dte_xml
                iv_sociedad TYPE bukrs
      EXPORTING ev_ok       TYPE abap_bool
                ev_mensaje  TYPE string.

    " REGLA 6: Monto DTE dentro de tolerancia respecto al doc. de referencia
    METHODS validate_monto
      IMPORTING is_dte      TYPE ty_dte_xml
                iv_sociedad TYPE bukrs
      EXPORTING ev_ok       TYPE abap_bool
                ev_mensaje  TYPE string.

    " Contabilización vía BAPI_INCOMINGINVOICE_CREATE
    METHODS contabilizar
      IMPORTING is_dte        TYPE ty_dte_xml
                iv_sociedad   TYPE bukrs
                it_posiciones TYPE tt_posiciones OPTIONAL
      EXPORTING ev_doc_fact   TYPE belnr_d
                ev_year_fact  TYPE gjahr
                ev_ok         TYPE abap_bool
                ev_mensaje    TYPE string.

    " Leer RUT de la sociedad desde T001 / datos de dirección
    METHODS get_rut_sociedad
      IMPORTING iv_sociedad    TYPE bukrs
      RETURNING VALUE(rv_rut)  TYPE string.

    " Leer RUT del proveedor desde LFA1-STCD1
    METHODS get_rut_proveedor
      IMPORTING iv_lifnr       TYPE lifnr
      RETURNING VALUE(rv_rut)  TYPE string.

    " Calcular monto pendiente de facturar para una OC/HES/EM
    METHODS get_monto_pendiente
      IMPORTING is_dte              TYPE ty_dte_xml
                iv_sociedad         TYPE bukrs
      RETURNING VALUE(rv_monto_clp) TYPE p.

    " Leer tipo de cambio para la fecha del DTE (tipo M)
    METHODS get_tipo_cambio
      IMPORTING iv_moneda    TYPE waers
                iv_fecha     TYPE dats
      RETURNING VALUE(rv_tc) TYPE p.

    " Leer tolerancias de ZDTE_CONFIG
    METHODS get_config
      IMPORTING iv_parametro   TYPE zdte_config-parametro
      RETURNING VALUE(rv_valor) TYPE zdte_config-valor_num.

ENDCLASS.

CLASS zcl_dte_processor IMPLEMENTATION.

  "============================================================================
  " PROCESO PRINCIPAL
  "============================================================================
  METHOD process_dte.
    ev_estado    = '05'.
    ev_log       = ''.
    ev_doc_fact  = ''.
    ev_year_fact = ''.

    " Parsear XML
    DATA ls_dte TYPE ty_dte_xml.
    TRY.
        ls_dte = parse_xml( iv_xml_data ).
      CATCH cx_dynamic_check INTO DATA(lx).
        ev_estado = '05'.
        ev_log    = |Error al parsear XML del DTE: { lx->get_text( ) }|.
        RETURN.
    ENDTRY.

    " Ejecutar reglas de negocio secuencialmente.
    " Si falla una regla, se detiene el procesamiento (estado 04).
    DATA lv_ok  TYPE abap_bool.
    DATA lv_msg TYPE string.

    " REGLA 1
    validate_referencia_xml(
      EXPORTING is_dte    = ls_dte
      IMPORTING ev_ok     = lv_ok
                ev_mensaje = lv_msg ).
    IF lv_ok = abap_false.
      ev_estado = '04'. ev_log = lv_msg. RETURN.
    ENDIF.

    " REGLA 2
    validate_doc_sap(
      EXPORTING is_dte     = ls_dte
                iv_sociedad = iv_sociedad
      IMPORTING ev_ok      = lv_ok
                ev_mensaje  = lv_msg ).
    IF lv_ok = abap_false.
      ev_estado = '04'. ev_log = lv_msg. RETURN.
    ENDIF.

    " REGLA 3
    validate_hes_oc(
      EXPORTING is_dte    = ls_dte
      IMPORTING ev_ok     = lv_ok
                ev_mensaje = lv_msg ).
    IF lv_ok = abap_false.
      ev_estado = '04'. ev_log = lv_msg. RETURN.
    ENDIF.

    " REGLA 4
    validate_sociedad(
      EXPORTING is_dte     = ls_dte
                iv_sociedad = iv_sociedad
      IMPORTING ev_ok      = lv_ok
                ev_mensaje  = lv_msg ).
    IF lv_ok = abap_false.
      ev_estado = '04'. ev_log = lv_msg. RETURN.
    ENDIF.

    " REGLA 5
    validate_proveedor(
      EXPORTING is_dte     = ls_dte
                iv_sociedad = iv_sociedad
      IMPORTING ev_ok      = lv_ok
                ev_mensaje  = lv_msg ).
    IF lv_ok = abap_false.
      ev_estado = '04'. ev_log = lv_msg. RETURN.
    ENDIF.

    " REGLA 6
    validate_monto(
      EXPORTING is_dte     = ls_dte
                iv_sociedad = iv_sociedad
      IMPORTING ev_ok      = lv_ok
                ev_mensaje  = lv_msg ).
    IF lv_ok = abap_false.
      ev_estado = '04'. ev_log = lv_msg. RETURN.
    ENDIF.

    " CONTABILIZAR
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

  "============================================================================
  " PROCESO CON POSICIONES EXPLÍCITAS
  "============================================================================
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

    " Con posiciones explícitas omitimos validate_monto — el usuario confirmó los montos

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

  "============================================================================
  " PARSE XML
  " Extrae campos del DTE chileno (SII) usando cl_ixml.
  " Estructura DTE: <DTE><Documento><Encabezado>...</Encabezado>
  "                                 <Referencia>...</Referencia>
  "                 </Documento></DTE>
  "============================================================================
  METHOD parse_xml.

    " Crear instancia iXML
    DATA(lo_ixml)   = cl_ixml=>create( ).
    DATA(lo_stream) = lo_ixml->create_istream_string( iv_xml ).
    DATA(lo_doc)    = lo_ixml->create_document( ).
    DATA(lo_parser) = lo_ixml->create_parser(
      istream  = lo_stream
      document = lo_doc ).

    DATA(lv_rc) = lo_parser->parse( ).
    IF lv_rc <> 0.
      DATA(lv_err_count) = lo_parser->num_errors( ).
      DATA(lv_err_text)  = |XML inválido. Errores del parser: { lv_err_count }|.
      IF lv_err_count > 0.
        DATA(lo_err) = lo_parser->get_error( index = 0 ).
        lv_err_text  = |{ lv_err_text } — { lo_err->get_reason( ) }|.
      ENDIF.
      RAISE EXCEPTION TYPE cx_dynamic_check
        MESSAGE ID 'ZDTE' TYPE 'E' NUMBER '001'
        WITH lv_err_text.
    ENDIF.

    " Navegar al nodo Encabezado
    DATA(lo_root)     = lo_doc->get_root_element( ).
    DATA(lo_enc)      = lo_root->find_from_name( name = 'Encabezado' ).

    IF lo_enc IS INITIAL.
      " Intentar con namespace — el DTE SII puede tener prefijo
      DATA(lo_iter) = lo_doc->create_iterator( ).
      DATA(lo_node) = lo_iter->get_next( ).
      WHILE lo_node IS NOT INITIAL.
        IF lo_node->get_name( ) = 'Encabezado'.
          lo_enc = lo_node.
          EXIT.
        ENDIF.
        lo_node = lo_iter->get_next( ).
      ENDWHILE.
    ENDIF.

    IF lo_enc IS INITIAL.
      RAISE EXCEPTION TYPE cx_dynamic_check
        MESSAGE ID 'ZDTE' TYPE 'E' NUMBER '002'
        WITH 'Nodo <Encabezado> no encontrado en el XML DTE'.
    ENDIF.

    " ---- IdDoc ----
    DATA(lo_iddoc) = lo_enc->find_from_name( name = 'IdDoc' ).
    rs_dte-tipo_dte      = CONV numc3( get_xml_value( io_parent = lo_iddoc iv_element = 'TipoDTE' ) ).
    rs_dte-folio         = get_xml_value( io_parent = lo_iddoc iv_element = 'Folio' ).

    " Fecha emisión: el XML viene en formato AAAA-MM-DD
    DATA(lv_fecha_str) = get_xml_value( io_parent = lo_iddoc iv_element = 'FchEmis' ).
    rs_dte-fecha_emision = CONV dats(
      lv_fecha_str(4) && lv_fecha_str+5(2) && lv_fecha_str+8(2) ).

    " Moneda: CLP por defecto; MntBruto puede ir en otra moneda para OC extranjeras
    DATA(lv_moneda) = get_xml_value( io_parent = lo_iddoc iv_element = 'TpoMoneda' ).
    rs_dte-moneda = COND #( WHEN lv_moneda IS INITIAL THEN 'CLP' ELSE lv_moneda ).

    " ---- Emisor (Proveedor) ----
    DATA(lo_emisor) = lo_enc->find_from_name( name = 'Emisor' ).
    rs_dte-rut_emisor  = normalize_rut(
      get_xml_value( io_parent = lo_emisor iv_element = 'RUTEmisor' ) ).
    rs_dte-razon_social = get_xml_value( io_parent = lo_emisor iv_element = 'RznSoc' ).

    " ---- Receptor (Sociedad) ----
    DATA(lo_recep) = lo_enc->find_from_name( name = 'Receptor' ).
    rs_dte-rut_receptor = normalize_rut(
      get_xml_value( io_parent = lo_recep iv_element = 'RUTRecep' ) ).

    " ---- Totales ----
    DATA(lo_tot) = lo_enc->find_from_name( name = 'Totales' ).
    rs_dte-monto_neto   = CONV p( get_xml_value( io_parent = lo_tot iv_element = 'MntNeto' ) ).
    rs_dte-monto_exento = CONV p( get_xml_value( io_parent = lo_tot iv_element = 'MntExe'  ) ).
    rs_dte-iva          = CONV p( get_xml_value( io_parent = lo_tot iv_element = 'IVA'     ) ).
    rs_dte-monto_total  = CONV p( get_xml_value( io_parent = lo_tot iv_element = 'MntTotal' ) ).

    " Impuestos adicionales (IEC, IVA no recuperable, IVA retenido)
    DATA(lo_imp) = lo_enc->find_from_name( name = 'ImptoReten' ).
    IF lo_imp IS NOT INITIAL.
      DATA(lv_tipo_imp) = get_xml_value( io_parent = lo_imp iv_element = 'TipoImp' ).
      CASE lv_tipo_imp.
        WHEN '14' OR '15'.  " Retención de IVA (parcial o total)
          rs_dte-iva_retenido = CONV p( get_xml_value( io_parent = lo_imp iv_element = 'MontoImp' ) ).
        WHEN '27' OR '271'. " IEC (Impuesto Específico al Combustible)
          rs_dte-iec = CONV p( get_xml_value( io_parent = lo_imp iv_element = 'MontoImp' ) ).
      ENDCASE.
    ENDIF.

    " ---- Referencias ----
    DATA(lt_refs) = get_xml_referencias( lo_doc ).
    rs_dte-tiene_ref = abap_false.

    LOOP AT lt_refs INTO DATA(ls_ref).
      CASE ls_ref-tipo_doc.
        WHEN '801'.       " Orden de Compra
          rs_dte-oc_ref    = CONV ebeln( ls_ref-folio_ref ).
          rs_dte-tiene_ref = abap_true.
        WHEN 'HES'.       " Hoja de Entrada de Servicios (código propio)
          rs_dte-hes_ref   = CONV belnr_d( ls_ref-folio_ref ).
          rs_dte-tiene_ref = abap_true.
        WHEN '700' OR '701'. " Entrada de Mercancías
          rs_dte-em_ref    = CONV belnr_d( ls_ref-folio_ref ).
          rs_dte-tiene_ref = abap_true.
        WHEN '33' OR '34'. " Referencia a factura (para NC/ND)
          rs_dte-folio_ref = ls_ref-folio_ref.
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.

  "============================================================================
  " HELPER: extraer texto de un nodo hijo
  "============================================================================
  METHOD get_xml_value.
    CHECK io_parent IS NOT INITIAL.
    DATA(lo_child) = io_parent->find_from_name( name = iv_element ).
    CHECK lo_child IS NOT INITIAL.
    DATA(lo_text) = lo_child->get_first_child( ).
    IF lo_text IS NOT INITIAL.
      rv_value = lo_text->get_value( ).
    ENDIF.
  ENDMETHOD.

  "============================================================================
  " HELPER: extraer todas las secciones <Referencia> del DTE
  "============================================================================
  METHOD get_xml_referencias.
    DATA(lo_iter) = io_doc->create_iterator( ).
    DATA(lo_node) = lo_iter->get_next( ).

    WHILE lo_node IS NOT INITIAL.
      IF lo_node->get_name( ) = 'Referencia'.
        DATA(ls_ref) = VALUE ty_referencia(
          nro_lin   = CONV i( get_xml_value( io_parent = lo_node iv_element = 'NroLinRef'  ) )
          tipo_doc  = get_xml_value( io_parent = lo_node iv_element = 'TpoDocRef' )
          folio_ref = get_xml_value( io_parent = lo_node iv_element = 'FolioRef'  )
        ).
        APPEND ls_ref TO rt_refs.
      ENDIF.
      lo_node = lo_iter->get_next( ).
    ENDWHILE.
  ENDMETHOD.

  "============================================================================
  " HELPER: normalizar RUT chileno → formato sin puntos con guión
  " Ej.: "76.543.210-9" → "76543210-9"
  "============================================================================
  METHOD normalize_rut.
    rv_rut = iv_rut.
    REPLACE ALL OCCURRENCES OF '.' IN rv_rut WITH ''.
    rv_rut = condense( rv_rut ).
  ENDMETHOD.

  "============================================================================
  " REGLA 1: Documento de referencia presente en el XML
  " Los DTE de servicios generales (agua, luz) se identifican por un indicador
  " en el BP y se eximen de esta validación.
  "============================================================================
  METHOD validate_referencia_xml.
    ev_ok = abap_false.

    " Verificar si el proveedor es de servicios generales (no requiere ref.)
    SELECT SINGLE @abap_true
      FROM lfa1
      WHERE stcd1 = @is_dte-rut_emisor
        AND ( lifnr IN (
                SELECT lifnr FROM lfm1
                WHERE zterm IS NOT INITIAL ) ) " Placeholder: ajustar campo indicador real
      INTO @DATA(lv_dummy).
    " TODO: reemplazar la condición anterior con el campo Z real que identifica
    " proveedores de servicios generales (ej.: campo Z en LFM1 o tabla ZDTE_PROV_SERV)

    " Verificar si es un indicador de proveedor de servicios generales
    DATA(lv_es_serv_gen) = abap_false.
    SELECT SINGLE @abap_true
      FROM zdte_config
      WHERE parametro = @( |PROV_SERV_{ is_dte-rut_emisor }| )
      INTO @DATA(lv_prov_config).
    IF sy-subrc = 0.
      lv_es_serv_gen = abap_true.
    ENDIF.

    IF lv_es_serv_gen = abap_true.
      " Proveedor de servicios generales: no requiere referencia
      ev_ok      = abap_true.
      ev_mensaje = 'Proveedor de servicios generales: omite validación de referencia'.
      RETURN.
    ENDIF.

    " Para NC y ND: se valida que exista referencia a una factura
    IF is_dte-tipo_dte = 56 OR is_dte-tipo_dte = 55. " NC o ND
      IF is_dte-folio_ref IS INITIAL AND is_dte-oc_ref IS INITIAL.
        ev_ok      = abap_false.
        ev_mensaje = |DTE tipo { is_dte-tipo_dte } sin referencia a factura ni OC.|
                   && ' El DTE queda sujeto a rechazo.'.
        RETURN.
      ENDIF.
      ev_ok = abap_true.
      RETURN.
    ENDIF.

    " Para facturas afectas (33), exentas (34), facturas de compra (46)
    IF is_dte-tiene_ref = abap_false OR
       ( is_dte-oc_ref IS INITIAL AND
         is_dte-hes_ref IS INITIAL AND
         is_dte-em_ref  IS INITIAL ).
      ev_ok      = abap_false.
      ev_mensaje = 'El DTE no contiene documentos de referencia (OC/HES/EM)'
               && ' en la sección <Referencia>. Sujeto a rechazo.'.
      RETURN.
    ENDIF.

    ev_ok      = abap_true.
    ev_mensaje = ''.
  ENDMETHOD.

  "============================================================================
  " REGLA 2: OC / HES / EM existen y están vigentes en SAP
  "============================================================================
  METHOD validate_doc_sap.
    ev_ok = abap_false.

    " Validar OC
    IF is_dte-oc_ref IS NOT INITIAL.
      SELECT SINGLE ebeln, bukrs, loekz, lifnr
        FROM ekko
        WHERE ebeln = @is_dte-oc_ref
        INTO @DATA(ls_ekko).

      IF sy-subrc <> 0.
        ev_ok      = abap_false.
        ev_mensaje = |OC { is_dte-oc_ref } no existe en SAP.|.
        RETURN.
      ENDIF.

      IF ls_ekko-loekz <> space.
        ev_ok      = abap_false.
        ev_mensaje = |OC { is_dte-oc_ref } está marcada para borrado (anulada).|.
        RETURN.
      ENDIF.

      IF ls_ekko-bukrs <> iv_sociedad.
        ev_ok      = abap_false.
        ev_mensaje = |OC { is_dte-oc_ref } pertenece a la sociedad { ls_ekko-bukrs }|
                   && |, no a { iv_sociedad }.|.
        RETURN.
      ENDIF.
    ENDIF.

    " Validar HES (tabla ESSR = Entry Sheet Service Record)
    IF is_dte-hes_ref IS NOT INITIAL.
      SELECT SINGLE lblni, loekz
        FROM essr
        WHERE lblni = @is_dte-hes_ref
        INTO @DATA(ls_essr).

      IF sy-subrc <> 0.
        ev_ok      = abap_false.
        ev_mensaje = |HES { is_dte-hes_ref } no existe en SAP.|.
        RETURN.
      ENDIF.

      IF ls_essr-loekz <> space.
        ev_ok      = abap_false.
        ev_mensaje = |HES { is_dte-hes_ref } está marcada para borrado.|.
        RETURN.
      ENDIF.
    ENDIF.

    " Validar EM (tabla MKPF)
    IF is_dte-em_ref IS NOT INITIAL.
      DATA(lv_gjahr_em) = sy-datum(4). " Se puede refinar si el año viene en la referencia
      SELECT SINGLE mblnr
        FROM mkpf
        WHERE mblnr = @is_dte-em_ref
          AND mjahr = @lv_gjahr_em
        INTO @DATA(lv_mblnr).

      IF sy-subrc <> 0.
        " Intentar año anterior
        lv_gjahr_em = sy-datum(4) - 1.
        SELECT SINGLE mblnr
          FROM mkpf
          WHERE mblnr = @is_dte-em_ref
            AND mjahr = @lv_gjahr_em
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

  "============================================================================
  " REGLA 3: HES/EM corresponde a la OC indicada
  "============================================================================
  METHOD validate_hes_oc.
    ev_ok = abap_false.

    " Sin OC en el DTE → no hay cruce que validar
    IF is_dte-oc_ref IS INITIAL.
      ev_ok = abap_true. RETURN.
    ENDIF.

    " Validar que la HES referencia la OC del DTE
    IF is_dte-hes_ref IS NOT INITIAL.
      SELECT SINGLE @abap_true
        FROM eslh                          " Service Entry Sheet Lines Header
        WHERE lblni  = @is_dte-hes_ref
          AND ebeln  = @is_dte-oc_ref
        INTO @DATA(lv_hes_oc).

      IF sy-subrc <> 0 OR lv_hes_oc <> abap_true.
        ev_ok      = abap_false.
        ev_mensaje = |HES { is_dte-hes_ref } no corresponde a la OC { is_dte-oc_ref }.|.
        RETURN.
      ENDIF.
    ENDIF.

    " Validar que la EM referencia la OC del DTE
    IF is_dte-em_ref IS NOT INITIAL.
      SELECT SINGLE @abap_true
        FROM mseg
        WHERE mblnr = @is_dte-em_ref
          AND ebeln = @is_dte-oc_ref
          AND bewtp = 'E'                  " Movimiento de entrada de mercancías
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

  "============================================================================
  " REGLA 4: Sociedad receptora del DTE = sociedad SAP
  " El RUT de la sociedad se lee de T001-STCEG (o campo de clasificación).
  "============================================================================
  METHOD validate_sociedad.
    ev_ok = abap_false.

    DATA(lv_rut_sociedad) = get_rut_sociedad( iv_sociedad ).

    IF lv_rut_sociedad IS INITIAL.
      ev_ok      = abap_false.
      ev_mensaje = |No se pudo determinar el RUT de la sociedad { iv_sociedad }.|
               && ' Configure el campo STCEG en T001.'.
      RETURN.
    ENDIF.

    DATA(lv_rut_recep_norm) = normalize_rut( is_dte-rut_receptor ).
    DATA(lv_rut_soc_norm)   = normalize_rut( lv_rut_sociedad ).

    IF lv_rut_recep_norm <> lv_rut_soc_norm.
      ev_ok      = abap_false.
      ev_mensaje = |RUT receptor del DTE ({ is_dte-rut_receptor }) no coincide|
               && | con el RUT de la sociedad { iv_sociedad } ({ lv_rut_sociedad }).|.
      RETURN.
    ENDIF.

    ev_ok      = abap_true.
    ev_mensaje = ''.
  ENDMETHOD.

  "============================================================================
  " REGLA 5: Proveedor del DTE = proveedor en el doc. de referencia SAP
  " Se obtiene el proveedor de la OC (EKKO-LIFNR) y se compara su RUT (LFA1-STCD1)
  " con el RUT emisor del DTE.
  "============================================================================
  METHOD validate_proveedor.
    ev_ok = abap_false.

    " Obtener proveedor de la OC
    DATA lv_lifnr_oc TYPE lifnr.
    IF is_dte-oc_ref IS NOT INITIAL.
      SELECT SINGLE lifnr
        FROM ekko
        WHERE ebeln = @is_dte-oc_ref
        INTO @lv_lifnr_oc.
    ELSEIF is_dte-hes_ref IS NOT INITIAL.
      " Obtener proveedor desde la HES → OC relacionada
      SELECT SINGLE ebeln
        FROM eslh
        WHERE lblni = @is_dte-hes_ref
        INTO @DATA(lv_ebeln_hes).
      IF sy-subrc = 0.
        SELECT SINGLE lifnr FROM ekko
          WHERE ebeln = @lv_ebeln_hes
          INTO @lv_lifnr_oc.
      ENDIF.
    ELSEIF is_dte-em_ref IS NOT INITIAL.
      SELECT SINGLE lifnr
        FROM mseg
        WHERE mblnr = @is_dte-em_ref
          AND bewtp = 'E'
        INTO @lv_lifnr_oc.
    ENDIF.

    IF lv_lifnr_oc IS INITIAL.
      ev_ok      = abap_false.
      ev_mensaje = 'No se pudo determinar el proveedor del documento de referencia en SAP.'.
      RETURN.
    ENDIF.

    " Leer RUT del proveedor SAP (campo STCD1 en LFA1 = número de identificación fiscal)
    DATA(lv_rut_sap) = normalize_rut( get_rut_proveedor( lv_lifnr_oc ) ).
    DATA(lv_rut_dte) = normalize_rut( is_dte-rut_emisor ).

    IF lv_rut_sap IS INITIAL.
      ev_ok      = abap_false.
      ev_mensaje = |Proveedor { lv_lifnr_oc } no tiene RUT (STCD1) en LFA1.|.
      RETURN.
    ENDIF.

    IF lv_rut_sap <> lv_rut_dte.
      ev_ok      = abap_false.
      ev_mensaje = |RUT emisor del DTE ({ is_dte-rut_emisor }) no coincide con el RUT|
               && | del proveedor { lv_lifnr_oc } en SAP ({ lv_rut_sap }).|.
      RETURN.
    ENDIF.

    ev_ok      = abap_true.
    ev_mensaje = ''.
  ENDMETHOD.

  "============================================================================
  " REGLA 6: Monto del DTE dentro de la tolerancia respecto al doc. de referencia
  " Lógica:
  "   - HES: el monto debe ser exactamente el total de la HES (no parcialidades)
  "   - EM:  puede haber parcialidades; se calcula el saldo pendiente de facturar
  "   - Se aplica una tolerancia: MIN(TOL_PORCENTAJE%, TOL_MONTO_CLP)
  "   - Para OC en moneda extranjera se convierte usando TC tipo M de la fecha del DTE
  "============================================================================
  METHOD validate_monto.
    ev_ok = abap_false.

    " Obtener tolerancias de configuración
    DATA(lv_tol_pct) = get_config( 'TOL_PORCENTAJE' ).  " Ej.: 5 (%)
    DATA(lv_tol_clp) = get_config( 'TOL_MONTO_CLP'  ).  " Ej.: 10000 (CLP)
    IF lv_tol_pct = 0. lv_tol_pct = 5.   ENDIF.         " Default 5%
    IF lv_tol_clp = 0. lv_tol_clp = 10000. ENDIF.       " Default 10.000 CLP

    " Obtener monto pendiente de facturar (en CLP)
    DATA(lv_monto_pend) = get_monto_pendiente(
      is_dte      = is_dte
      iv_sociedad = iv_sociedad ).

    IF lv_monto_pend = 0.
      ev_ok      = abap_false.
      ev_mensaje = 'No existe saldo pendiente de facturar en el documento de referencia.'.
      RETURN.
    ENDIF.

    " Convertir monto del DTE a CLP si es necesario
    DATA lv_monto_dte_clp TYPE p LENGTH 15 DECIMALS 2.
    IF is_dte-moneda = 'CLP' OR is_dte-moneda IS INITIAL.
      lv_monto_dte_clp = is_dte-monto_total.
    ELSE.
      DATA(lv_tc) = get_tipo_cambio(
        iv_moneda = is_dte-moneda
        iv_fecha  = is_dte-fecha_emision ).
      lv_monto_dte_clp = is_dte-monto_total * lv_tc.
    ENDIF.

    " Calcular diferencia absoluta
    DATA(lv_diferencia) = abs( lv_monto_dte_clp - lv_monto_pend ).

    " Calcular tolerancia aplicable: la que se cumpla primero
    DATA(lv_tol_por_pct) = lv_monto_pend * lv_tol_pct / 100.
    DATA(lv_tol_aplicada) = COND p(
      WHEN lv_tol_por_pct < lv_tol_clp THEN lv_tol_por_pct
      ELSE lv_tol_clp ).

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

  "============================================================================
  " CONTABILIZACION
  " Usa BAPI_INCOMINGINVOICE_CREATE (transacción MIRO equivalente).
  " Soporta facturas de bienes (EM) y servicios (HES).
  " Para NC/ND: usa el mismo BAPI referenciando el documento original.
  "============================================================================
  METHOD contabilizar.
    ev_ok        = abap_false.
    ev_doc_fact  = ''.
    ev_year_fact = ''.
    ev_mensaje   = ''.

    " ---- Header ----
    DATA(ls_header) = VALUE bapi_incinv_create_header(
      invoice_ind  = abap_true                    " Es una factura (no NC/ND aquí)
      doc_date     = is_dte-fecha_emision
      pstng_date   = cl_abap_context_info=>get_system_date( )
      comp_code    = iv_sociedad
      currency     = COND #( WHEN is_dte-moneda IS INITIAL THEN 'CLP'
                             ELSE is_dte-moneda )
      gross_amount = is_dte-monto_total
      calc_tax_ind = abap_false                   " IVA ya viene calculado en el DTE
      ref_doc_no   = is_dte-folio                 " Folio DTE como referencia externa
    ).

    " NC y ND: ajustar indicador
    IF is_dte-tipo_dte = 56.  " Nota de crédito
      ls_header-invoice_ind = abap_false.
    ELSEIF is_dte-tipo_dte = 55.  " Nota de débito
      ls_header-invoice_ind = abap_true.
    ENDIF.

    " ---- Items: construir desde posiciones o desde OC/HES/EM ----
    DATA lt_items  TYPE TABLE OF bapi_incinv_create_item.
    DATA lt_taxitm TYPE TABLE OF bapi_incinv_create_tax.
    DATA lv_cnt    TYPE i VALUE 1.

    IF it_posiciones IS SUPPLIED AND it_posiciones IS NOT INITIAL.
      " Posiciones explícitas indicadas por el usuario
      LOOP AT it_posiciones INTO DATA(ls_pos).
        APPEND VALUE bapi_incinv_create_item(
          invoice_doc_item = lv_cnt
          po_number        = is_dte-oc_ref
          po_item          = ls_pos-posicion
          quantity         = ls_pos-cantidad
          po_unit          = ls_pos-unidad
          sheet_no         = is_dte-hes_ref
        ) TO lt_items.
        lv_cnt += 1.
      ENDLOOP.

    ELSEIF is_dte-hes_ref IS NOT INITIAL.
      " Basado en HES: se factura el total de la HES
      SELECT lblni, ebeln, ebelp, wrbtr
        FROM essr
        WHERE lblni = @is_dte-hes_ref
        INTO TABLE @DATA(lt_hes).

      LOOP AT lt_hes INTO DATA(ls_hes).
        APPEND VALUE bapi_incinv_create_item(
          invoice_doc_item = lv_cnt
          po_number        = ls_hes-ebeln
          po_item          = ls_hes-ebelp
          sheet_no         = is_dte-hes_ref
          item_amount      = ls_hes-wrbtr
          quantity         = 1
        ) TO lt_items.
        lv_cnt += 1.
      ENDLOOP.

    ELSEIF is_dte-em_ref IS NOT INITIAL.
      " Basado en EM: posiciones del documento de material
      SELECT mblnr, zeile, ebeln, ebelp, menge, meins, dmbtr
        FROM mseg
        WHERE mblnr = @is_dte-em_ref
          AND ebeln = @is_dte-oc_ref
          AND bewtp = 'E'
        INTO TABLE @DATA(lt_mseg).

      LOOP AT lt_mseg INTO DATA(ls_mseg).
        APPEND VALUE bapi_incinv_create_item(
          invoice_doc_item = lv_cnt
          po_number        = ls_mseg-ebeln
          po_item          = ls_mseg-ebelp
          ref_doc          = ls_mseg-mblnr
          ref_doc_it       = ls_mseg-zeile
          quantity         = ls_mseg-menge
          po_unit          = ls_mseg-meins
          item_amount      = ls_mseg-dmbtr
        ) TO lt_items.
        lv_cnt += 1.
      ENDLOOP.
    ENDIF.

    " ---- Impuestos ----
    " IVA recuperable (código de impuesto configurado en el sistema)
    IF is_dte-iva > 0.
      APPEND VALUE bapi_incinv_create_tax(
        tax_code      = 'V1'   " Ajustar al código de IVA configurado en el mandante
        tax_amount    = is_dte-iva
        tax_base_amount = is_dte-monto_neto
      ) TO lt_taxitm.
    ENDIF.

    " IVA retenido (código de impuesto específico para retención)
    IF is_dte-iva_retenido > 0.
      APPEND VALUE bapi_incinv_create_tax(
        tax_code      = 'VR'   " Ajustar al código de IVA retenido
        tax_amount    = is_dte-iva_retenido
        tax_base_amount = is_dte-monto_neto
      ) TO lt_taxitm.
    ENDIF.

    " ---- Llamada al BAPI ----
    DATA lt_return   TYPE TABLE OF bapiret2.
    DATA lv_doc_no   TYPE bapi_incinv_fld-inv_doc_no.
    DATA lv_fisc_yr  TYPE bapi_incinv_fld-fisc_year.

    CALL FUNCTION 'BAPI_INCOMINGINVOICE_CREATE'
      EXPORTING
        headerdata       = ls_header
      IMPORTING
        invoicedocnumber = lv_doc_no
        fiscalyear       = lv_fisc_yr
      TABLES
        itemdata         = lt_items
        taxdata          = lt_taxitm
        return           = lt_return.

    " Verificar resultado
    DATA(lt_errors) = FILTER #( lt_return WHERE type = 'E' OR type = 'A' ).

    IF lt_errors IS INITIAL.
      " Sin errores → confirmar con COMMIT
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING wait = abap_true.

      ev_ok        = abap_true.
      ev_doc_fact  = lv_doc_no.
      ev_year_fact = lv_fisc_yr.
      ev_mensaje   = |DTE contabilizado: documento { lv_doc_no } / { lv_fisc_yr }.|.
    ELSE.
      " Hay errores → ROLLBACK
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

      DATA(lt_msgs) = VALUE string_table(
        FOR ls_err IN lt_errors
        ( |[{ ls_err-type }] { ls_err-message }| ) ).

      ev_ok      = abap_false.
      ev_mensaje = |Error en contabilización: { concat_lines_of( table = lt_msgs sep = `; ` ) }|.
    ENDIF.
  ENDMETHOD.

  "============================================================================
  " HELPER: RUT de la sociedad desde T001-STCEG (NIF fiscal)
  "============================================================================
  METHOD get_rut_sociedad.
    SELECT SINGLE stceg
      FROM t001
      WHERE bukrs = @iv_sociedad
      INTO @rv_rut.
  ENDMETHOD.

  "============================================================================
  " HELPER: RUT del proveedor desde LFA1-STCD1 (número identificación fiscal)
  "============================================================================
  METHOD get_rut_proveedor.
    SELECT SINGLE stcd1
      FROM lfa1
      WHERE lifnr = @iv_lifnr
      INTO @rv_rut.
  ENDMETHOD.

  "============================================================================
  " HELPER: Calcular saldo pendiente de facturar
  " HES: monto total de la HES menos facturas ya contabilizadas
  " EM:  sumatoria de MSEG-DMBTR de las posiciones no facturadas aún
  "============================================================================
  METHOD get_monto_pendiente.

    IF is_dte-hes_ref IS NOT INITIAL.
      " --- HES: monto total de la hoja de entrada de servicios ---
      SELECT SINGLE wrbtr
        FROM essr
        WHERE lblni = @is_dte-hes_ref
        INTO @DATA(lv_monto_hes).

      " Restar facturas ya contabilizadas contra esta HES (RSEG-WRBTR)
      DATA lv_facturado TYPE p LENGTH 15 DECIMALS 2.
      SELECT SUM( wrbtr )
        FROM rseg
        WHERE lblni = @is_dte-hes_ref
        INTO @lv_facturado.

      rv_monto_clp = lv_monto_hes - lv_facturado.

    ELSEIF is_dte-em_ref IS NOT INITIAL.
      " --- EM: saldo pendiente por posición = valor EM - facturado previo ---
      SELECT SUM( dmbtr )
        FROM mseg
        WHERE mblnr = @is_dte-em_ref
          AND ebeln = @is_dte-oc_ref
          AND bewtp = 'E'
        INTO @DATA(lv_monto_em).

      SELECT SUM( wrbtr )
        FROM rseg
        WHERE ebeln = @is_dte-oc_ref
        INTO @lv_facturado.

      rv_monto_clp = lv_monto_em - lv_facturado.

    ELSEIF is_dte-oc_ref IS NOT INITIAL.
      " --- Solo OC: valor neto de la OC pendiente de facturar ---
      SELECT SUM( netwr )
        FROM ekpo
        WHERE ebeln = @is_dte-oc_ref
          AND loekz = @space
        INTO @DATA(lv_netwr_oc).

      SELECT SUM( wrbtr )
        FROM rseg
        WHERE ebeln = @is_dte-oc_ref
        INTO @lv_facturado.

      rv_monto_clp = lv_netwr_oc - lv_facturado.
    ENDIF.

    " Convertir a CLP si la moneda del doc. de referencia no es CLP
    IF is_dte-moneda <> 'CLP' AND is_dte-moneda IS NOT INITIAL.
      DATA(lv_tc) = get_tipo_cambio(
        iv_moneda = is_dte-moneda
        iv_fecha  = is_dte-fecha_emision ).
      rv_monto_clp = rv_monto_clp * lv_tc.
    ENDIF.

  ENDMETHOD.

  "============================================================================
  " HELPER: Tipo de cambio para la fecha del DTE (tipo M = medio)
  "============================================================================
  METHOD get_tipo_cambio.
    rv_tc = 1. " Default: misma moneda

    IF iv_moneda = 'CLP' OR iv_moneda IS INITIAL.
      RETURN.
    ENDIF.

    CALL FUNCTION 'READ_EXCHANGE_RATE'
      EXPORTING
        date             = iv_fecha
        foreign_currency = iv_moneda
        local_currency   = 'CLP'
        type_of_rate     = 'M'
      IMPORTING
        exchange_rate    = rv_tc
      EXCEPTIONS
        OTHERS           = 1.

    IF sy-subrc <> 0 OR rv_tc = 0.
      rv_tc = 1.
    ENDIF.
  ENDMETHOD.

  "============================================================================
  " HELPER: Leer parámetro numérico de ZDTE_CONFIG
  "============================================================================
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
