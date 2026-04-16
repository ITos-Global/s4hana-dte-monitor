@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Monitor DTE Proveedor - Interface View'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_DTE_MONITOR
  as select from zdte_monitor as m
  composition [0..*] of ZI_DTE_MONITOR_H as _Historial
  association [0..1] to I_BusinessPartnerAddress as _BP
    on  $projection.ProveedorSap = _BP.BusinessPartner
    and _BP.AddressRepresentationCode = 'INT'
{
      //-- Claves --------------------------------------------------
  key m.tipo_dte                    as TipoDte,
  key m.folio                       as Folio,
  key m.proveedor                   as Proveedor,

      //-- Identificacion ------------------------------------------
      m.sociedad                    as Sociedad,
      m.prov_sap                    as ProveedorSap,
      m.nombre_prov                 as NombreProveedor,

      //-- Fechas --------------------------------------------------
      m.fe_fact                     as FechaDocumento,
      m.fe_cont                     as FechaContabilizacion,
      m.fe_recep                    as FechaRecepcionSii,
      m.fe_acept                    as FechaAceptacion,
      m.fe_venc                     as FechaVencimiento,

      //-- Estado --------------------------------------------------
      m.estado                      as Estado,

      //-- Criticality para color en SmartTable --------------------
      //  1=Error(rojo), 2=Warning(amarillo), 3=Success(verde), 0=None
      case m.estado
        when '01' then cast( 2 as abap.int1 )  -- Pendiente   : warning
        when '02' then cast( 3 as abap.int1 )  -- Aprobado    : success
        when '03' then cast( 1 as abap.int1 )  -- Rechazado   : error
        when '04' then cast( 1 as abap.int1 )  -- Por rechazar: error
        when '05' then cast( 1 as abap.int1 )  -- No procesado: error
        when '06' then cast( 3 as abap.int1 )  -- Contabilizado: success
        else            cast( 0 as abap.int1 )
      end                           as Criticality,

      //-- Montos --------------------------------------------------
      m.waers                       as Moneda,
      @Semantics.amount.currencyCode: 'Moneda'
      m.monto_n                     as MontoNeto,
      @Semantics.amount.currencyCode: 'Moneda'
      m.monto_ex                    as MontoExento,
      @Semantics.amount.currencyCode: 'Moneda'
      m.iec                         as Iec,
      @Semantics.amount.currencyCode: 'Moneda'
      m.iva_rec                     as IvaRecuperable,
      @Semantics.amount.currencyCode: 'Moneda'
      m.iva_nrec                    as IvaNoRecuperable,
      @Semantics.amount.currencyCode: 'Moneda'
      m.iva_ret                     as IvaRetenido,
      @Semantics.amount.currencyCode: 'Moneda'
      m.total_doc                   as TotalDocumento,

      //-- Documento SAP generado ----------------------------------
      m.doc_fact                    as DocumentoFacturaSap,
      m.year_fact                   as AnioFacturaSap,

      //-- Documentos de referencia --------------------------------
      m.oc                          as OrdenCompra,
      m.em                          as EntradaMercancia,
      m.year_em                     as AnioEntradaMercancia,
      m.hes                         as HojaEntradaServicio,
      m.folio_ref                   as FolioReferencia,

      //-- Datos internos ------------------------------------------
      m.xml_data                    as XmlData,
      m.log_proc                    as LogProcesamiento,
      m.dias_pend                   as DiasPendientes,

      //-- Auditoría -----------------------------------------------
      @Semantics.systemDate.createdAt: true
      m.erdat                       as FechaCreacion,
      m.erzet                       as HoraCreacion,
      @Semantics.user.createdBy: true
      m.ernam                       as UsuarioCreacion,
      @Semantics.systemDate.lastChangedAt: true
      m.aedat                       as FechaModificacion,
      @Semantics.user.lastChangedBy: true
      m.aenam                       as UsuarioModificacion,

      //-- Asociaciones --------------------------------------------
      _Historial,
      _BP
}
