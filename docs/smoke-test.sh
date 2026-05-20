#!/usr/bin/env bash
# Smoke test del Monitor DTE — corre desde bash/WSL.
# Uso: ./smoke-test.sh
#
# Requiere: curl, jq (opcional para parsing).

set -e

URL="https://my419159-api.s4hana.cloud.sap/sap/opu/odata4/sap/zui_dte_monitor_o4/srvd/sap/zui_dte_monitor/0001"
AUTH="COM_MONITOR:5Nt[#L4>K2/8xAy7#6+nMFNlsGC-x9Gb~5&b]%o]"
COOKIES=/tmp/dte_cookies.txt
rm -f "$COOKIES"

# Folio único basado en timestamp (para no chocar con tests previos)
FOLIO=$(date +%s | tail -c 7)
TS=$(date +%Y-%m-%d)

echo "================================================"
echo "Smoke Test Monitor DTE — Folio de prueba: $FOLIO"
echo "================================================"

# 1) Fetch CSRF
echo -e "\n--- [1/5] Fetch CSRF token ---"
CSRF=$(curl -s -k -c "$COOKIES" -u "$AUTH" -H "x-csrf-token: fetch" -I "$URL/" \
       | grep -i "x-csrf-token" | awk '{print $2}' | tr -d '\r\n')
echo "CSRF: $CSRF"

# 2) IngestFromXml (TC-01)
echo -e "\n--- [2/5] TC-01: IngestFromXml — XML válido tipo 33 ---"
XML="<?xml version=\"1.0\" encoding=\"UTF-8\"?><DTE><Encabezado><IdDoc><TipoDTE>33</TipoDTE><Folio>${FOLIO}</Folio><FchEmis>2026-05-10</FchEmis></IdDoc><Emisor><RUTEmisor>76543210-9</RUTEmisor><RznSoc>SERVICIOS MINEROS S.A.</RznSoc></Emisor><Receptor><RUTRecep>76188363-1</RUTRecep><RznSocRecep>FENIX GOLD S.A.</RznSocRecep></Receptor><Totales><MntNeto>1500000</MntNeto><TasaIVA>19</TasaIVA><IVA>285000</IVA><MntTotal>1785000</MntTotal></Totales></Encabezado><Referencia><NroLinRef>1</NroLinRef><TpoDocRef>801</TpoDocRef><FolioRef>4500012345</FolioRef></Referencia><Referencia><NroLinRef>2</NroLinRef><TpoDocRef>HES</TpoDocRef><FolioRef>1000000123</FolioRef></Referencia></DTE>"
BODY=$(jq -n --arg xml "$XML" '{XmlData:$xml}')
curl -s -k -b "$COOKIES" -u "$AUTH" \
  -H "Content-Type: application/json" -H "Accept: application/json" \
  -H "x-csrf-token: $CSRF" \
  -X POST "$URL/DteMonitor/com.sap.gateway.srvd.zui_dte_monitor.v0001.IngestFromXml" \
  -d "$BODY" \
  -w "HTTP %{http_code}\n"

# 3) Estado después de IngestFromXml
echo -e "\n--- [3/5] GET registro tras IngestFromXml (debería estar en '01' Pendiente) ---"
curl -s -k -b "$COOKIES" -u "$AUTH" \
  "$URL/DteMonitor(TipoDte='033',Folio='${FOLIO}',Proveedor='76543210-9')?\$select=TipoDte,Folio,Proveedor,Sociedad,NombreProveedor,Estado,LogProcesamiento,FechaRecepcionSii" \
  -w "\nHTTP %{http_code}\n"

# 4) IngestFromSii — dispara AutoProcess y validaciones (TC-25)
echo -e "\n--- [4/5] TC-25: IngestFromSii — setea FE_RECEP, dispara pipeline ---"
SII_BODY=$(cat <<EOF
{
  "TipoDte": "033",
  "Folio": "${FOLIO}",
  "Proveedor": "76543210-9",
  "Sociedad": "76188363-1",
  "FechaRecepcionSii": "${TS}",
  "FechaDocumento": "2026-05-10",
  "Moneda": "CLP",
  "MontoTotal": 1785000
}
EOF
)
curl -s -k -b "$COOKIES" -u "$AUTH" \
  -H "Content-Type: application/json" -H "Accept: application/json" \
  -H "x-csrf-token: $CSRF" \
  -X POST "$URL/DteMonitor/com.sap.gateway.srvd.zui_dte_monitor.v0001.IngestFromSii" \
  -d "$SII_BODY" \
  -w "HTTP %{http_code}\n"

# 5) Estado final
echo -e "\n--- [5/5] GET registro tras IngestFromSii (esperás '02' Validado o '04' Por Rechazar) ---"
curl -s -k -b "$COOKIES" -u "$AUTH" \
  "$URL/DteMonitor(TipoDte='033',Folio='${FOLIO}',Proveedor='76543210-9')?\$select=TipoDte,Folio,Proveedor,Sociedad,BukrsSap,ProveedorSap,NombreProveedor,Estado,LogProcesamiento,FechaRecepcionSii" \
  -w "\nHTTP %{http_code}\n"

echo -e "\n================================================"
echo "Smoke test terminado. Folio probado: $FOLIO"
echo "================================================"
