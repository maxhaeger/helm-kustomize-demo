Absolut. Hier ist der **überarbeitete Produktstandard**, der sich **ausschließlich** auf die von Ihnen bereitgestellten Nominatim Konfigurationsmöglichkeiten konzentriert. Der Fokus liegt dabei auf den sicherheitsrelevanten Einstellungen, formatiert für die Übernahme in Confluence oder Markdown.

---

# BWI Produktstandard: Nominatim Geocoding Service (Docker Container)

*Version: 1.0 | Stand: 2025-12-01 | Geltungsbereich: Alle Projekte mit Geocoding-Bedarf*

Dieser Standard definiert die **verbindliche Konfiguration** des Nominatim Docker Containers basierend auf den dokumentierten Umgebungsvariablen (`.env` oder Shell-Variablen).

---

## 1. Sicherheitsrelevante Konfiguration (Muss-Anforderungen)

Diese Einstellungen müssen zwingend konfiguriert werden, um die internen Sicherheitsrichtlinien zu erfüllen und die Angriffsfläche zu minimieren.

### 1.1. Zugangsdaten- und Datenbank-Sicherheit

Die direkteste Quelle für Sicherheitsrisiken sind persistente Anmeldedaten. Die Konfiguration muss das Prinzip des **Least Privilege** umsetzen.

| Config-Variable | Standardvorgabe | Begründung/Hinweis |
| :--- | :--- | :--- |
| **Passwort** in `NOMINATIM_DATABASE_DSN` | **VERBOTEN** | Passwörter **dürfen nicht** statisch im Container-Image oder der Konfigurationsdatei (`.env`) gespeichert werden. Es muss ein **Secrets Management Tool** zur Laufzeit zur Injektion der Zugangsdaten verwendet werden (z.B. über ein **Password File** oder ein **Init-Container**). |
| `NOMINATIM_DATABASE_WEBUSER` | **Dedizierter Webuser** | Der Postgres-User, unter dem der Webserver läuft, muss **minimal privilegierte** Rechte (`SELECT`) auf die benötigten Tabellen besitzen. Der Standarduser (`www-data`) muss ggf. umbenannt werden, falls er nicht der BWI-Nomenklatur entspricht. |
| `NOMINATIM_HTTP_PROXY_LOGIN` & `NOMINATIM_HTTP_PROXY_PASSWORD` | **Injektion über Secrets Management** | Falls die Replikation einen Proxy benötigt (`NOMINATIM_HTTP_PROXY=enabled`), dürfen diese Logins ebenfalls **nur** über das zentrale Secrets Management zur Laufzeit injiziert werden. |

### 1.2. API- und Zugriffskontrolle

| Config-Variable | Standardvorgabe | Begründung/Hinweis |
| :--- | :--- | :--- |
| `NOMINATIM_CORS_NOACCESSCONTROL` | **`no`** | Der Standardwert (`yes`) setzt den Header `access-control-allow-origin: *`, was **unzulässig** ist. Zur Sicherstellung der BWI-Richtlinien muss dieser auf **`no`** gesetzt werden, oder es muss eine kontrollierte Whitelist über ein davor geschaltetes **API Gateway** oder **Reverse Proxy** erzwungen werden. |
| `NOMINATIM_LOOKUP_MAX_COUNT` | **Max. 50** | Beschränkt die Anzahl der IDs, die in einer `/lookup`-Anfrage abgefragt werden können. Dies dient der **Ressourcenkontrolle** und zur Vermeidung von DoS-Angriffen durch Einzelabfragen. |
| `NOMINATIM_POLYGON_OUTPUT_MAX_TYPES` | **Max. 1** | Das Anfordern verschiedener Geometrieformate ist rechenintensiv. Die Begrenzung auf maximal einen Typ pro Anfrage reduziert die potenzielle Last. |

### 1.3. System-Härtung

| Config-Variable | Standardvorgabe | Begründung/Hinweis |
| :--- | :--- | :--- |
| **Container User** | **Non-Root-User** | Der Container muss zwingend als Non-Root-User ausgeführt werden, idealerweise der als `NOMINATIM_DATABASE_WEBUSER` definierte User. |
| `NOMINATIM_DEBUG_SQL` | **`no`** | Muss im Produktivbetrieb **deaktiviert** sein. Das Debug-Logging kann sensible Informationen über die interne Datenbankstruktur und Abfragen preisgeben. |

---

## 2. Betriebs- und Performance-Anforderungen

Diese Parameter sind für die Stabilität und Wartbarkeit des Dienstes notwendig.

### 2.1. Ressourcen-Management und Timeouts

| Config-Variable | Standardvorgabe | Funktion/Erläuterung |
| :--- | :--- | :--- |
| `NOMINATIM_API_POOL_SIZE` | **Max. 10** | Setzt die maximale Anzahl von Datenbankverbindungen pro Worker. Muss mit den Limits des PostgreSQL-Servers (`max_connections`) koordiniert werden. |
| `NOMINATIM_QUERY_TIMEOUT` | **Max. 10s** | Erzwingt einen **Timeout** für einzelne SQL-Abfragen im Backend. Schützt vor ineffizienten Abfragen. |
| `NOMINATIM_REQUEST_TIMEOUT` | **Max. 60s** | Schließt eine gesamte Suchanfrage ab, wenn diese länger dauert. Schützt den Endanwender vor ewigen Wartezeiten. |
| `NOMINATIM_REPLICATION_MAX_DIFF` | **Max. 50 MB** | Reduziert die RAM-Nutzung während der Updates. Dies ist kritisch in Umgebungen, in denen das Frontend gleichzeitig Anfragen bedient. |

### 2.2. Import-Integrität und Wartung

| Config-Variable | Standardvorgabe | Funktion/Erläuterung |
| :--- | :--- | :--- |
| `NOMINATIM_FLATNODE_FILE` | **Pfad muss definiert werden** | Für große Imports (Planet-Scale) wird dieses File benötigt. Der Pfad muss **persistent** sein, da das Flatnode-File für **alle Updates** und `add-data`-Prozesse zwingend erforderlich ist. |
| `NOMINATIM_OSM2PGSQL_BINARY` | **Leer lassen** | Es ist zwingend der mit Nominatim gebündelte `osm2pgsql`-Binary zu verwenden, um Kompatibilitätsprobleme zu vermeiden. |
| `NOMINATIM_TOKENIZER` | **`icu`** (Standard) | **Achtung:** Dieser Wert kann nach dem initialen Import **nicht mehr geändert werden**. Die Wahl muss vor dem ersten Datenimport getroffen werden. |

---

## 3. Log-Anforderungen

| Config-Variable | Standardvorgabe | Funktion/Erläuterung |
| :--- | :--- | :--- |
| `NOMINATIM_LOG_FILE` | **Leer lassen** | Das Logging muss über `stdout`/`stderr` erfolgen (Docker-Standard), um die zentrale BWI-Log-Aggregationslösung zu nutzen. |
| `NOMINATIM_LOG_FORMAT` | **Standardformat akzeptieren** | Die zentrale Log-Erfassung muss für das Parsing des Default-Formats konfiguriert werden, um Metriken wie `total_time` und `query_string` zu extrahieren. |

Möchten Sie, dass ich Ihnen einen **Strukturvorschlag** für die **Basis-Konfigurationsdatei (`.env`)** erstelle, der diese Vorgaben umsetzt?
