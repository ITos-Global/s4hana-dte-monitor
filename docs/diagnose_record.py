import requests, json

URL  = "https://my419159-api.s4hana.cloud.sap/sap/opu/odata4/sap/zui_dte_monitor_o4/srvd/sap/zui_dte_monitor/0001"
USER = "COM_MONITOR"
PWD  = "5Nt[#L4>K2/8xAy7#6+nMFNlsGC-x9Gb~5&b]%o]"

s = requests.Session()
s.auth = (USER, PWD)
s.headers.update({"Accept": "application/json"})
r = s.head(URL + "/", headers={"x-csrf-token": "fetch"}, timeout=30)
r.raise_for_status()
s.headers["x-csrf-token"] = r.headers["x-csrf-token"]
s.headers["Content-Type"] = "application/json"

key    = "DteMonitor(TipoDte='033',Folio='100010',Proveedor='76948695-K')"
fields = "TipoDte,Folio,Proveedor,Estado,LogProcesamiento,OrdenCompra,HojaEntradaServicio,XmlData"
r2 = s.get(f"{URL}/{key}?$select={fields}", timeout=30)
print("GET HTTP", r2.status_code)
if r2.status_code == 200:
    d = r2.json()
    print("Estado      :", d.get("Estado"))
    print("Log         :", (d.get("LogProcesamiento") or "")[:120])
    print("OrdenCompra :", repr(d.get("OrdenCompra")))
    print("HES         :", repr(d.get("HojaEntradaServicio")))
    xml = d.get("XmlData") or ""
    print("XmlData len :", len(xml))
    print("XmlData[:100]:", repr(xml[:100]))
else:
    print(r2.text[:500])
