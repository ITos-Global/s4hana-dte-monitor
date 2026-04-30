CLASS lhc_dtemonitor DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR DteMonitor RESULT result.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR DteMonitor RESULT result.
    METHODS ingest_from_xml FOR MODIFY
      IMPORTING keys FOR ACTION DteMonitor~IngestFromXml.
    METHODS ingest_from_sii FOR MODIFY
      IMPORTING keys FOR ACTION DteMonitor~IngestFromSii.
    METHODS reprocesar FOR MODIFY
      IMPORTING keys FOR ACTION DteMonitor~Reprocesar RESULT result.
    METHODS rechazar FOR MODIFY
      IMPORTING keys FOR ACTION DteMonitor~Rechazar RESULT result.
    METHODS indicar_doc_referencia FOR MODIFY
      IMPORTING keys FOR ACTION DteMonitor~IndicarDocReferencia RESULT result.
    METHODS indicar_posiciones FOR MODIFY
      IMPORTING keys FOR ACTION DteMonitor~IndicarPosiciones RESULT result.
    METHODS get_montos_pendientes FOR READ
      IMPORTING keys FOR FUNCTION DteMonitor~GetMontosPendientes RESULT result.
    METHODS set_dias_pendientes FOR DETERMINE ON MODIFY
      IMPORTING keys FOR DteMonitor~SetDiasPendientes.
    METHODS auto_process FOR DETERMINE ON MODIFY
      IMPORTING keys FOR DteMonitor~AutoProcess.
    METHODS crear_historial FOR DETERMINE ON SAVE
      IMPORTING keys FOR DteMonitor~CrearHistorial.
    METHODS validate_doc_referencia FOR VALIDATE ON SAVE
      IMPORTING keys FOR DteMonitor~ValidateDocReferencia.
ENDCLASS.
