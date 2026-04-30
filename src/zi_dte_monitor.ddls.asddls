@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Monitor DTE Proveedor - Interface View'
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_DTE_MONITOR
  as select from zdte_monitor as m
  composition [0..*] of ZI_DTE_MONITOR_H as _Historial
{
  key m.tipo_dte                    as TipoDte,
  key m.folio                       as Folio,
  key m.proveedor                   as Proveedor,

      m.sociedad                    as Sociedad,
      m.bukrs_sap                   as BukrsSap,
      m.prov_sap                    as ProveedorSap,
      m.nombre_prov                 as NombreProveedor,

      m.fe_fact                     as FechaDocumento,
      m.fe_cont                     as FechaContabilizacion,
      m.fe_recep                    as FechaRecepcionSii,
      m.fe_acept                    as FechaAceptacion,
      m.fe_venc                     as FechaVencimiento,

      m.estado                      as Estado,

      case m.estado
        when '01' then cast( 2 as abap.int1 )
        when '02' then cast( 3 as abap.int1 )
        when '03' then cast( 1 as abap.int1 )
        when '04' then cast( 1 as abap.int1 )
        when '05' then cast( 1 as abap.int1 )
        when '06' then cast( 3 as abap.int1 )
        else            cast( 0 as abap.int1 )
      end                           as Criticality,

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

      m.doc_fact                    as DocumentoFacturaSap,
      m.year_fact                   as AnioFacturaSap,

      m.oc                          as OrdenCompra,
      m.em                          as EntradaMercancia,
      m.year_em                     as AnioEntradaMercancia,
      m.hes                         as HojaEntradaServicio,
      m.folio_ref                   as FolioReferencia,

      m.xml_data                    as XmlData,
      m.log_proc                    as LogProcesamiento,
      m.dias_pend                   as DiasPendientes,

      m.erdat                       as FechaCreacion,
      m.erzet                       as HoraCreacion,
      m.ernam                       as UsuarioCreacion,
      m.aedat                       as FechaModificacion,
      m.aenam                       as UsuarioModificacion,

      _Historial
}
