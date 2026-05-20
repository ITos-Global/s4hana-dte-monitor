CLASS zcl_dte_http_invoice DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_item,
             po_number   TYPE ebeln,
             po_item     TYPE ebelp,
             ses_number  TYPE char10,    " ServiceEntrySheet zero-padded
             ses_item    TYPE numc5,
             quantity    TYPE menge_d,
             unit        TYPE meins,
             amount      TYPE p LENGTH 15 DECIMALS 2,
             currency    TYPE waers,
           END OF ty_item.
    TYPES tt_items TYPE STANDARD TABLE OF ty_item WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_header,
             is_credit_memo TYPE abap_bool,
             document_date  TYPE dats,
             posting_date   TYPE dats,
             company_code   TYPE bukrs,
             currency       TYPE waers,
             gross_amount   TYPE p LENGTH 15 DECIMALS 2,
             folio_sii      TYPE char20,
             items          TYPE tt_items,
           END OF ty_header.

    TYPES: BEGIN OF ty_result,
             ok               TYPE abap_bool,
             supplier_invoice TYPE belnr_d,
             fiscal_year      TYPE gjahr,
             message          TYPE string,
             http_status      TYPE i,
           END OF ty_result.

    CLASS-METHODS post_invoice
      IMPORTING is_header        TYPE ty_header
      RETURNING VALUE(rs_result) TYPE ty_result.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS gc_api_path TYPE string VALUE
      `/sap/opu/odata/sap/API_SUPPLIERINVOICE_PROCESS_SRV/A_SupplierInvoice`.

    CONSTANTS gc_comm_scenario   TYPE c LENGTH 30 VALUE 'SAP_COM_0057'.
    CONSTANTS gc_comm_service_id TYPE c LENGTH 40 VALUE 'API_SUPPLIERINVOICE_PROC_SRV_0001_IWSG'.

    CLASS-METHODS build_json
      IMPORTING is_header      TYPE ty_header
      RETURNING VALUE(rv_json) TYPE string.

    CLASS-METHODS parse_response
      IMPORTING iv_body          TYPE string
                iv_status        TYPE i
      RETURNING VALUE(rs_result) TYPE ty_result.

    CLASS-METHODS extract_between
      IMPORTING iv_text       TYPE string
                iv_after      TYPE string
                iv_delim      TYPE string
      RETURNING VALUE(rv_val) TYPE string.

    CLASS-METHODS date_to_epoch_ms
      IMPORTING iv_date      TYPE dats
      RETURNING VALUE(rv_ms) TYPE string.

ENDCLASS.


CLASS zcl_dte_http_invoice IMPLEMENTATION.

  METHOD post_invoice.
    rs_result-ok = abap_false.

    TRY.
        " Obtener destination via Communication Arrangement (SAP_COM_0057)
        DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
                          comm_scenario = gc_comm_scenario
                          service_id    = gc_comm_service_id ).
        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).

        " --- Fetch CSRF ---
        DATA(lo_req) = lo_client->get_http_request( ).
        lo_req->set_uri_path( gc_api_path ).
        lo_req->set_query( '$top=0' ).
        lo_req->set_header_fields( VALUE #(
          ( name = 'x-csrf-token' value = 'fetch' )
          ( name = 'Accept'       value = 'application/json' )
        ) ).
        DATA(lo_resp_csrf) = lo_client->execute( if_web_http_client=>get ).
        DATA(lt_hdr) = lo_resp_csrf->get_header_fields( ).

        DATA lv_csrf TYPE string.
        LOOP AT lt_hdr INTO DATA(ls_h).
          IF to_lower( ls_h-name ) = 'x-csrf-token'.
            lv_csrf = ls_h-value.
            EXIT.
          ENDIF.
        ENDLOOP.

        IF lv_csrf IS INITIAL.
          rs_result-message = 'No se pudo obtener CSRF token. Revisar Communication Arrangement SAP_COM_0046.'.
          RETURN.
        ENDIF.

        " --- POST factura ---
        DATA(lv_json) = build_json( is_header ).

        DATA(lo_req2) = lo_client->get_http_request( ).
        lo_req2->set_uri_path( gc_api_path ).
        lo_req2->set_header_fields( VALUE #(
          ( name = 'Accept'       value = 'application/json' )
          ( name = 'Content-Type' value = 'application/json' )
          ( name = 'x-csrf-token' value = lv_csrf )
        ) ).
        lo_req2->set_text( lv_json ).

        DATA(lo_resp) = lo_client->execute( if_web_http_client=>post ).
        DATA(lv_status) = lo_resp->get_status( )-code.
        DATA(lv_body)   = lo_resp->get_text( ).
        lo_client->close( ).

        rs_result = parse_response( iv_body = lv_body iv_status = lv_status ).

      CATCH cx_root INTO DATA(lx).
        rs_result-ok          = abap_false.
        rs_result-http_status = 0.
        rs_result-message     = |Error de conexión: { lx->get_text( ) }|.
    ENDTRY.
  ENDMETHOD.

  METHOD build_json.
    " Construye JSON V2 OData con header + items
    DATA lv_items TYPE string.
    DATA lv_idx TYPE i VALUE 0.

    LOOP AT is_header-items INTO DATA(ls_it).
      lv_idx = lv_idx + 1.
      " 5 digits zero-padded (n LENGTH 5 hace el zero-pad implicito al asignar)
      DATA lv_item_no TYPE n LENGTH 5.
      lv_item_no = lv_idx.

      DATA(lv_item) = |\{|
        && |"SupplierInvoiceItem":"{ lv_item_no }",|
        && |"PurchaseOrder":"{ ls_it-po_number }",|
        && |"PurchaseOrderItem":"{ ls_it-po_item }",|
        && |"ServiceEntrySheet":"{ ls_it-ses_number }",|
        && |"ServiceEntrySheetItem":"{ ls_it-ses_item }",|
        && |"QuantityInPurchaseOrderUnit":"{ ls_it-quantity }",|
        && |"PurchaseOrderQuantityUnit":"{ ls_it-unit }",|
        && |"SupplierInvoiceItemAmount":"{ ls_it-amount }",|
        && |"DocumentCurrency":"{ ls_it-currency }"|
        && |\}|.

      IF lv_items IS NOT INITIAL.
        lv_items = lv_items && ','.
      ENDIF.
      lv_items = lv_items && lv_item.
    ENDLOOP.

    DATA(lv_credit) = COND string( WHEN is_header-is_credit_memo = abap_true
                                    THEN 'true' ELSE 'false' ).

    rv_json = |\{|
      && |"CompanyCode":"{ is_header-company_code }",|
      && |"DocumentDate":"/Date({ date_to_epoch_ms( is_header-document_date ) })/",|
      && |"PostingDate":"/Date({ date_to_epoch_ms( is_header-posting_date ) })/",|
      && |"InvoiceGrossAmount":"{ is_header-gross_amount }",|
      && |"DocumentCurrency":"{ is_header-currency }",|
      && |"SupplierInvoiceIDByInvcgParty":"{ is_header-folio_sii }",|
      && |"SupplierInvoiceIsCreditMemo":{ lv_credit },|
      && |"TaxIsCalculatedAutomatically":false,|
      && |"to_SupplierInvoiceItemPurOrdRef":\{"results":[{ lv_items }]\}|
      && |\}|.
  ENDMETHOD.

  METHOD parse_response.
    rs_result-http_status = iv_status.

    IF iv_status BETWEEN 200 AND 299.
      rs_result-ok = abap_true.
      DATA(lv_inv) = extract_between(
        iv_text  = iv_body
        iv_after = '"SupplierInvoice":"'
        iv_delim = '"' ).
      IF lv_inv IS NOT INITIAL.
        rs_result-supplier_invoice = CONV belnr_d( lv_inv ).
      ENDIF.

      DATA(lv_yr) = extract_between(
        iv_text  = iv_body
        iv_after = '"FiscalYear":"'
        iv_delim = '"' ).
      IF lv_yr IS NOT INITIAL.
        rs_result-fiscal_year = CONV gjahr( lv_yr ).
      ENDIF.

      rs_result-message = |Factura creada: { rs_result-supplier_invoice } / { rs_result-fiscal_year }|.
    ELSE.
      rs_result-ok = abap_false.
      DATA(lv_err) = extract_between(
        iv_text  = iv_body
        iv_after = '"value":"'
        iv_delim = '"' ).
      IF lv_err IS NOT INITIAL.
        rs_result-message = lv_err.
      ELSE.
        rs_result-message = |HTTP { iv_status }: { iv_body(200) }|.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD extract_between.
    " Helper: busca iv_after en iv_text y devuelve lo que hay hasta iv_delim
    DATA lv_pos TYPE i.
    FIND iv_after IN iv_text MATCH OFFSET lv_pos.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lv_start) = lv_pos + strlen( iv_after ).
    DATA(lv_rest)  = iv_text+lv_start.

    DATA lv_end TYPE i.
    FIND iv_delim IN lv_rest MATCH OFFSET lv_end.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    rv_val = lv_rest(lv_end).
  ENDMETHOD.

  METHOD date_to_epoch_ms.
    " Convierte dats (YYYYMMDD) a milisegundos epoch (formato OData V2 /Date(ms)/).
    " Aprovecha la sustracción nativa de dats que devuelve la diferencia en dias.
    CONSTANTS lc_epoch_base TYPE dats VALUE '19700101'.
    DATA(lv_days) = CONV i( iv_date - lc_epoch_base ).
    DATA lv_ms_p  TYPE p LENGTH 12.
    lv_ms_p = lv_days * 86400000.
    rv_ms = |{ lv_ms_p }|.
  ENDMETHOD.

ENDCLASS.
