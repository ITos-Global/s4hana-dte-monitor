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
        when '01' then cast( 0 as abap.int1 )
        when '02' then cast( 3 as abap.int1 )
        when '03' then cast( 1 as abap.int1 )
        when '04' then cast( 2 as abap.int1 )
        when '05' then cast( 1 as abap.int1 )
        when '06' then cast( 5 as abap.int1 )
        when '07' then cast( 2 as abap.int1 )
        else            cast( 0 as abap.int1 )
      end                           as Criticality,

      m.waers                       as Moneda,
      // Montos del DTE expuestos como valor externo para evitar reescalado por moneda en Fiori.
      cast( GET_NUMERIC_VALUE( m.monto_n ) as abap.dec( 15, 2 ) )     as MontoNeto,
      cast( GET_NUMERIC_VALUE( m.monto_ex ) as abap.dec( 15, 2 ) )    as MontoExento,
      cast( GET_NUMERIC_VALUE( m.iec ) as abap.dec( 15, 2 ) )         as Iec,
      cast( GET_NUMERIC_VALUE( m.iva_rec ) as abap.dec( 15, 2 ) )     as IvaRecuperable,
      cast( GET_NUMERIC_VALUE( m.iva_nrec ) as abap.dec( 15, 2 ) )    as IvaNoRecuperable,
      cast( GET_NUMERIC_VALUE( m.iva_ret ) as abap.dec( 15, 2 ) )     as IvaRetenido,
      cast( GET_NUMERIC_VALUE( m.total_doc ) as abap.dec( 15, 2 ) )   as TotalDocumento,

      m.doc_fact                    as DocumentoFacturaSap,
      m.year_fact                   as AnioFacturaSap,

      m.oc                          as OrdenCompra,
      m.em                          as EntradaMercancia,
      m.year_em                     as AnioEntradaMercancia,
      m.hes                         as HojaEntradaServicio,
      m.folio_ref                   as FolioReferencia,

      m.motivo_nc                   as MotivoNc,
      m.material_doc_ref            as MaterialDocRef,
      m.material_doc_ref_y          as MaterialDocRefAnio,
      m.doc_fact_origen             as DocFacturaOrigen,

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
