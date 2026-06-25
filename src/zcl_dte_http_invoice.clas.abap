CLASS zcl_dte_http_invoice DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_item,
             po_number       TYPE ebeln,
             po_item         TYPE ebelp,
             ses_number      TYPE char10,    " ServiceEntrySheet zero-padded (HES) o vacio
             ses_item        TYPE numc5,
             quantity        TYPE menge_d,
             unit            TYPE meins,
             amount          TYPE p LENGTH 15 DECIMALS 2,
             currency        TYPE waers,
             " --- Campos opcionales para flujo EM (spec) ---
             tax_code        TYPE mwskz,     " C1 (33) / C0 (34); vacio = omitir
             ref_doc         TYPE belnr_d,   " ReferenceDocument (EM doc number)
             ref_doc_year    TYPE gjahr,     " ReferenceDocumentFiscalYear
             ref_doc_item    TYPE numc4,     " ReferenceDocumentItem (MaterialDocumentItem = NUMC4, ej '0001')
             is_subsequent   TYPE abap_bool, " IsSubsequentDebitCredit ('X') para ND tipo 56
           END OF ty_item.
    TYPES tt_items TYPE STANDARD TABLE OF ty_item WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_gl_item,
             amount            TYPE p LENGTH 15 DECIMALS 2,
             currency          TYPE waers,
             tax_code          TYPE mwskz,
             gl_account        TYPE c LENGTH 10,
             cost_center       TYPE c LENGTH 10,
             wbs_element       TYPE c LENGTH 24,
             debit_credit_code TYPE c LENGTH 1,
           END OF ty_gl_item.
    TYPES tt_gl_items TYPE STANDARD TABLE OF ty_gl_item WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_tax,
             tax_amount TYPE p LENGTH 15 DECIMALS 2,
             currency   TYPE waers,
             tax_code   TYPE mwskz,
           END OF ty_tax.
    TYPES tt_taxes TYPE STANDARD TABLE OF ty_tax WITH DEFAULT KEY.

    TYPES: BEGIN OF ty_header,
             is_credit_memo  TYPE abap_bool,
             document_date   TYPE dats,
             posting_date    TYPE dats,
             company_code    TYPE bukrs,
             currency        TYPE waers,
             gross_amount    TYPE p LENGTH 15 DECIMALS 2,
             folio_sii       TYPE char20,
             " --- Campos opcionales para flujo EM (spec) ---
             invoicing_party    TYPE lifnr,   " Supplier SAP
             due_calc_date      TYPE dats,    " DueCalculationBaseDate
             tax_determination_date TYPE dats,
             acct_doc_type      TYPE c LENGTH 2,  " AccountingDocumentType (ej. 'RE')
             header_text        TYPE c LENGTH 50, " DocumentHeaderText
             items              TYPE tt_items,
             gl_items           TYPE tt_gl_items,
             taxes              TYPE tt_taxes,
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

    " Path relativo al outbound service ZOS_SUPPLIERINVOICE_REST.
    " El Communication Arrangement ya aporta:
    " /sap/opu/odata/sap/API_SUPPLIERINVOICE_PROCESS_SRV/
    CONSTANTS gc_api_path TYPE string VALUE `/A_SupplierInvoice`.

    CONSTANTS gc_comm_scenario   TYPE c LENGTH 30 VALUE 'ZSD_DTE_MONITOR'.
    CONSTANTS gc_comm_service_id TYPE c LENGTH 40 VALUE 'ZOS_SUPPLIERINVOICE_REST'.
    CONSTANTS gc_accept_language TYPE string VALUE 'es'.

    CLASS-METHODS build_json
      IMPORTING is_header      TYPE ty_header
      RETURNING VALUE(rv_json) TYPE string.

    CLASS-METHODS parse_response
      IMPORTING iv_body          TYPE string
                iv_status        TYPE i
      RETURNING VALUE(rs_result) TYPE ty_result.

    CLASS-METHODS extract_error_message
      IMPORTING iv_body           TYPE string
      RETURNING VALUE(rv_message) TYPE string.

    CLASS-METHODS extract_between
      IMPORTING iv_text       TYPE string
                iv_after      TYPE string
                iv_delim      TYPE string
      RETURNING VALUE(rv_val) TYPE string.

    CLASS-METHODS date_to_epoch_ms
      IMPORTING iv_date      TYPE dats
      RETURNING VALUE(rv_ms) TYPE string.

    CLASS-METHODS to_commercial_unit
      IMPORTING iv_unit        TYPE meins
      RETURNING VALUE(rv_unit) TYPE string.

ENDCLASS.


CLASS zcl_dte_http_invoice IMPLEMENTATION.

  METHOD post_invoice.
    rs_result-ok = abap_false.

    TRY.
        " Obtener destination via Communication Arrangement ZSD_DTE_MONITOR.
        DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
                          comm_scenario = gc_comm_scenario
                          service_id    = gc_comm_service_id ).

        " --- Fetch CSRF (client #1) ---
        DATA(lo_client_csrf) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
        DATA(lo_req) = lo_client_csrf->get_http_request( ).
        lo_req->set_uri_path( gc_api_path ).
        lo_req->set_header_fields( VALUE #(
          ( name = 'x-csrf-token'    value = 'fetch' )
          ( name = 'Accept'          value = 'application/json' )
          ( name = 'Accept-Language' value = gc_accept_language )
        ) ).
        DATA(lo_resp_csrf) = lo_client_csrf->execute( if_web_http_client=>get ).
        DATA(lv_csrf_status) = lo_resp_csrf->get_status( )-code.
        DATA(lt_hdr) = lo_resp_csrf->get_header_fields( ).
        DATA(lt_cookies) = lo_resp_csrf->get_cookies( ).
        lo_client_csrf->close( ).

        DATA lv_csrf TYPE string.
        LOOP AT lt_hdr INTO DATA(ls_h).
          IF to_lower( ls_h-name ) = 'x-csrf-token'.
            lv_csrf = ls_h-value.
            EXIT.
          ENDIF.
        ENDLOOP.

        IF lv_csrf IS INITIAL.
          rs_result-http_status = lv_csrf_status.
          rs_result-message = 'No se pudo conectar con el servicio de creación de facturas.'.
          RETURN.
        ENDIF.

        " --- POST factura (client #2, fresh) ---
        DATA(lv_json) = build_json( is_header ).
        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
        DATA(lo_req2) = lo_client->get_http_request( ).
        lo_req2->set_uri_path( gc_api_path ).
        " Propagar cookies (de a una, no hay set_cookies bulk)
        LOOP AT lt_cookies INTO DATA(ls_ck).
          lo_req2->set_cookie( i_name = ls_ck-name i_value = ls_ck-value ).
        ENDLOOP.
        lo_req2->set_header_fields( VALUE #(
          ( name = 'Accept'          value = 'application/json' )
          ( name = 'Accept-Language' value = gc_accept_language )
          ( name = 'Content-Type'    value = 'application/json' )
          ( name = 'x-csrf-token'    value = lv_csrf )
        ) ).
        lo_req2->set_text( lv_json ).

        DATA(lo_resp) = lo_client->execute( if_web_http_client=>post ).
        DATA(lv_status) = lo_resp->get_status( )-code.
        DATA(lv_body)   = lo_resp->get_text( ).
        lo_client->close( ).

        rs_result = parse_response( iv_body = lv_body iv_status = lv_status ).

      CATCH cx_root.
        rs_result-ok          = abap_false.
        rs_result-http_status = 0.
        rs_result-message     = 'No se pudo conectar con el servicio de creación de facturas.'.
    ENDTRY.
  ENDMETHOD.

  METHOD build_json.
    " Construye JSON V2 OData con header + items
    DATA lv_items TYPE string.
    DATA lv_gl_items TYPE string.
    DATA lv_taxes TYPE string.
    DATA lv_idx TYPE i VALUE 0.

    LOOP AT is_header-items INTO DATA(ls_it).
      lv_idx = lv_idx + 1.
      " 5 digits zero-padded (n LENGTH 5 hace el zero-pad implicito al asignar)
      DATA lv_item_no TYPE n LENGTH 5.
      lv_item_no = lv_idx.

      " Campos opcionales (solo EM): TaxCode + ReferenceDocument*
      DATA lv_extra_it TYPE string.
      CLEAR lv_extra_it.
      IF ls_it-tax_code IS NOT INITIAL.
        lv_extra_it = lv_extra_it && |,"TaxCode":"{ ls_it-tax_code }"|.
      ENDIF.
      " IsSubsequentDebitCredit: 'X' marca la posicion como cargo/abono posterior
      " (ND tipo 56 = aumento del valor ya facturado).
      IF ls_it-is_subsequent = abap_true.
        lv_extra_it = lv_extra_it && |,"IsSubsequentDebitCredit":"X"|.
      ENDIF.
      IF ls_it-ref_doc IS NOT INITIAL.
        lv_extra_it = lv_extra_it && |,"ReferenceDocument":"{ ls_it-ref_doc }"|.
        IF ls_it-ref_doc_year IS NOT INITIAL.
          lv_extra_it = lv_extra_it && |,"ReferenceDocumentFiscalYear":"{ ls_it-ref_doc_year }"|.
        ENDIF.
        IF ls_it-ref_doc_item IS NOT INITIAL.
          lv_extra_it = lv_extra_it && |,"ReferenceDocumentItem":"{ ls_it-ref_doc_item }"|.
        ENDIF.
      ENDIF.

      " ServiceEntrySheet solo se emite si viene informado (HES). Para EM se omite.
      DATA lv_ses_part TYPE string.
      CLEAR lv_ses_part.
      IF ls_it-ses_number IS NOT INITIAL.
        lv_ses_part = |"ServiceEntrySheet":"{ ls_it-ses_number }",|
                   && |"ServiceEntrySheetItem":"{ ls_it-ses_item }",|.
      ENDIF.

      DATA(lv_unit) = to_commercial_unit( ls_it-unit ).

      DATA(lv_item) = |\{|
        && |"SupplierInvoiceItem":"{ lv_item_no }",|
        && |"PurchaseOrder":"{ ls_it-po_number }",|
        && |"PurchaseOrderItem":"{ ls_it-po_item }",|
        && lv_ses_part
        && |"QuantityInPurchaseOrderUnit":"{ ls_it-quantity DECIMALS = 3 NUMBER = RAW }",|
        && |"PurchaseOrderQuantityUnit":"{ lv_unit }",|
        && |"SupplierInvoiceItemAmount":"{ ls_it-amount DECIMALS = 2 NUMBER = RAW }",|
        && |"DocumentCurrency":"{ ls_it-currency }"|
        && lv_extra_it
        && |\}|.

      IF lv_items IS NOT INITIAL.
        lv_items = lv_items && ','.
      ENDIF.
      lv_items = lv_items && lv_item.
    ENDLOOP.

    CLEAR lv_idx.
    LOOP AT is_header-gl_items INTO DATA(ls_gl).
      lv_idx = lv_idx + 1.
      " API metadata: A_SupplierInvoiceItemGLAcct.SupplierInvoiceItem es NUMC4.
      DATA lv_gl_item_no TYPE n LENGTH 4.
      lv_gl_item_no = lv_idx.

      DATA(lv_debit_credit) = COND string(
        WHEN ls_gl-debit_credit_code IS NOT INITIAL THEN ls_gl-debit_credit_code
        ELSE 'S' ).

      DATA(lv_account_assignment) = COND string(
        WHEN ls_gl-cost_center IS NOT INITIAL THEN |,"CostCenter":"{ ls_gl-cost_center }"|
        WHEN ls_gl-wbs_element IS NOT INITIAL THEN |,"WBSElement":"{ ls_gl-wbs_element }"|
        ELSE `` ).

      DATA(lv_gl_item) = |\{|
        && |"SupplierInvoiceItem":"{ lv_gl_item_no }",|
        && |"DocumentCurrency":"{ ls_gl-currency }",|
        && |"DebitCreditCode":"{ lv_debit_credit }",|
        && |"SupplierInvoiceItemAmount":"{ ls_gl-amount DECIMALS = 2 NUMBER = RAW }",|
        && |"TaxCode":"{ ls_gl-tax_code }",|
        && |"GLAccount":"{ ls_gl-gl_account }"|
        && lv_account_assignment
        && |\}|.

      IF lv_gl_items IS NOT INITIAL.
        lv_gl_items = lv_gl_items && ','.
      ENDIF.
      lv_gl_items = lv_gl_items && lv_gl_item.
    ENDLOOP.

    CLEAR lv_idx.
    LOOP AT is_header-taxes INTO DATA(ls_tax).
      lv_idx = lv_idx + 1.

      DATA(lv_tax) = |\{|
        && |"TaxCode":"{ ls_tax-tax_code }",|
        && |"DocumentCurrency":"{ ls_tax-currency }",|
        && |"TaxAmount":"{ ls_tax-tax_amount DECIMALS = 3 NUMBER = RAW }"|
        && |\}|.

      IF lv_taxes IS NOT INITIAL.
        lv_taxes = lv_taxes && ','.
      ENDIF.
      lv_taxes = lv_taxes && lv_tax.
    ENDLOOP.

    " SupplierInvoiceIsCreditMemo es Edm.String segun metadata, NO Edm.Boolean
    " El patron SAP es: 'X' = es credit memo, '' = no es
    DATA(lv_credit) = COND string( WHEN is_header-is_credit_memo = abap_true
                                    THEN 'X' ELSE '' ).

    " Folio sin espacios trailing (char20 -> trim)
    DATA(lv_folio_trim) = condense( CONV string( is_header-folio_sii ) ).

    DATA(lv_doc_date_ms)  = date_to_epoch_ms( is_header-document_date ).
    DATA(lv_post_date_ms) = date_to_epoch_ms( is_header-posting_date ).
    DATA(lv_tax_det_date) = COND dats(
      WHEN is_header-tax_determination_date IS NOT INITIAL
        THEN is_header-tax_determination_date
      ELSE is_header-document_date ).
    DATA(lv_tax_det_ms) = date_to_epoch_ms( lv_tax_det_date ).
    DATA(lv_tax_is_auto) = COND string(
      WHEN lv_taxes IS INITIAL THEN 'true'
      ELSE 'false' ).

    " Campos opcionales del header (solo EM): InvoicingParty / DueCalcBaseDate /
    " AccountingDocumentType / DocumentHeaderText. HES no los manda y mantiene
    " el comportamiento previo.
    DATA lv_extra_hd TYPE string.
    CLEAR lv_extra_hd.
    IF is_header-invoicing_party IS NOT INITIAL.
      lv_extra_hd = lv_extra_hd && |,"InvoicingParty":"{ is_header-invoicing_party }"|.
    ENDIF.
    IF is_header-due_calc_date IS NOT INITIAL.
      DATA(lv_due_ms) = date_to_epoch_ms( is_header-due_calc_date ).
      lv_extra_hd = lv_extra_hd && |,"DueCalculationBaseDate":"/Date({ lv_due_ms })/"|.
    ENDIF.
    IF is_header-acct_doc_type IS NOT INITIAL.
      lv_extra_hd = lv_extra_hd && |,"AccountingDocumentType":"{ is_header-acct_doc_type }"|.
    ENDIF.
    IF is_header-header_text IS NOT INITIAL.
      lv_extra_hd = lv_extra_hd && |,"DocumentHeaderText":"{ is_header-header_text }"|.
    ENDIF.

    rv_json = |\{|
      && |"CompanyCode":"{ is_header-company_code }",|
      && |"DocumentDate":"/Date({ lv_doc_date_ms })/",|
      && |"PostingDate":"/Date({ lv_post_date_ms })/",|
      && |"TaxDeterminationDate":"/Date({ lv_tax_det_ms })/",|
      && |"InvoiceGrossAmount":"{ is_header-gross_amount DECIMALS = 2 NUMBER = RAW }",|
      && |"DocumentCurrency":"{ is_header-currency }",|
      && |"SupplierInvoiceIDByInvcgParty":"{ lv_folio_trim }",|
      && |"SupplierInvoiceIsCreditMemo":"{ lv_credit }",|
      && |"TaxIsCalculatedAutomatically":{ lv_tax_is_auto }|
      && lv_extra_hd.

    IF lv_items IS NOT INITIAL.
      rv_json = rv_json
        && |,|
        && |"to_SuplrInvcItemPurOrdRef":\{"results":[{ lv_items }]\}|.
    ENDIF.
    IF lv_gl_items IS NOT INITIAL.
      rv_json = rv_json
        && |,|
        && |"to_SupplierInvoiceItemGLAcct":\{"results":[{ lv_gl_items }]\}|.
    ENDIF.
    IF lv_taxes IS NOT INITIAL.
      rv_json = rv_json
        && |,|
        && |"to_SupplierInvoiceTax":\{"results":[{ lv_taxes }]\}|.
    ENDIF.

    rv_json = rv_json && |\}|.
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

      IF rs_result-supplier_invoice IS INITIAL OR rs_result-fiscal_year IS INITIAL.
        rs_result-ok = abap_false.
        rs_result-message = 'No se pudo confirmar la factura creada en SAP.'.
      ELSE.
        rs_result-message = |Factura creada: { rs_result-supplier_invoice } / { rs_result-fiscal_year }|.
      ENDIF.
    ELSE.
      rs_result-ok = abap_false.
      DATA(lv_err) = extract_error_message( iv_body ).
      IF lv_err IS NOT INITIAL.
        rs_result-message = lv_err.
      ELSE.
        rs_result-message = 'No se pudo crear la factura en SAP.'.
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD extract_error_message.
    rv_message = extract_between(
      iv_text  = iv_body
      iv_after = '"value":"'
      iv_delim = '"' ).

    IF rv_message IS INITIAL.
      rv_message = extract_between(
        iv_text  = iv_body
        iv_after = '"message":"'
        iv_delim = '"' ).
    ENDIF.

    IF rv_message IS INITIAL.
      RETURN.
    ENDIF.

    REPLACE ALL OCCURRENCES OF '\n' IN rv_message WITH ' '.
    REPLACE ALL OCCURRENCES OF '\r' IN rv_message WITH ' '.
    REPLACE ALL OCCURRENCES OF '\t' IN rv_message WITH ' '.
    REPLACE ALL OCCURRENCES OF '\"' IN rv_message WITH '"'.
    CONDENSE rv_message.

    IF strlen( rv_message ) > 220.
      rv_message = rv_message(220).
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
    " NUMBER = RAW evita el formato locale (puntos como sep. miles, coma decimal)
    rv_ms = |{ lv_ms_p NUMBER = RAW }|.
  ENDMETHOD.

  METHOD to_commercial_unit.
    rv_unit = condense( CONV string( iv_unit ) ).

    IF iv_unit IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE UnitOfMeasure_E
      FROM I_UnitOfMeasureText
      WHERE Language      = 'S'
        AND UnitOfMeasure = @iv_unit
      INTO @DATA(lv_unit_es).

    IF sy-subrc = 0 AND lv_unit_es IS NOT INITIAL.
      rv_unit = condense( CONV string( lv_unit_es ) ).
    ELSE.
      rv_unit = condense( CONV string( iv_unit ) ).
    ENDIF.

    TRANSLATE rv_unit TO UPPER CASE.
  ENDMETHOD.

ENDCLASS.

