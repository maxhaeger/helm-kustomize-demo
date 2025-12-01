Das ist eine wichtige Information, die den Produktstandard direkt beeinflusst, insbesondere im Bereich der **Secrets-Verwaltung**.

Da **HashiCorp Vault** im Einsatz ist und die Datenbank-Infrastruktur aus **MariaDB Galera (Cluster)** und **MaxScale (Proxy/Router)** besteht, muss der Produktstandard präziser festlegen, wie der Nominatim-Container seine Zugangsdaten sicher bezieht.

Ich passe den Standard nun an, um die Verwendung von Vault zu **verbindlichen** und die Konfiguration der Datenbankverbindung entsprechend zu präzisieren.

---

# BWI Produktstandard: Nominatim Geocoding Service (Docker Container)

*Version: 1.1 (Vault/MariaDB Galera Anpassung) | Stand: 2025-12-01 | Geltungsbereich: Alle Projekte mit Geocoding-Bedarf*

Dieser Standard definiert die **verbindliche Konfiguration** des Nominatim Docker Containers, unter besonderer Berücksichtigung der **HashiCorp Vault Integration** und der **MaxScale-Anbindung**.

---

## 1. Sicherheitsrelevante Konfiguration (Muss-Anforderungen)

### 1.1. Secrets- und Zugangsdaten-Management (Vault-Integration)

Die Verwendung von statischen Passwörtern ist **untersagt**. Der Nominatim-Container muss dynamische Secrets von HashiCorp Vault über eine der folgenden Methoden beziehen:

| Config-Variable | Standardvorgabe | Begründung/Hinweis |
| :--- | :--- | :--- |
| **Passwort** in `NOMINATIM_DATABASE_DSN` | **VERBOTEN** | **Ausschließlich** dynamische Secrets von Vault verwenden. |
| **Vault-Integration** | **Verbindlich** | Der Nominatim-Pod/Container muss einen **Sidecar-Container** (z.B. den **Vault Agent**) nutzen, um dynamische Secrets zu beziehen und diese zur Laufzeit in das Dateisystem oder in Umgebungsvariablen zu injizieren.  |
| `NOMINATIM_DATABASE_DSN` | **Anbindung über MaxScale** | Die DSN muss den **MaxScale-Proxy** als Host referenzieren, um die Galera-Cluster-Lastverteilung und Read/Write-Trennung zu gewährleisten. Format: `pgsql:dbname=nominatim;host=<MaxScale-Service-IP/DNS>;port=<MaxScale-Port>` |
| `NOMINATIM_DATABASE_WEBUSER` | **Dynamisch generierter User** | Der User muss über das **Vault Database Secret Backend** für die MariaDB Galera **dynamisch generiert** werden. |
| `NOMINATIM_HTTP_PROXY_LOGIN` & `NOMINATIM_HTTP_PROXY_PASSWORD` | **Vault Secrets** | Falls benötigt, müssen Proxy-Zugangsdaten ebenfalls über Vault bezogen werden. |

### 1.2. API- und Zugriffskontrolle

Diese Einstellungen sind weiterhin zur Einhaltung der Basis-Sicherheit kritisch.

| Config-Variable | Standardvorgabe | Begründung/Hinweis |
| :--- | :--- | :--- |
| `NOMINATIM_CORS_NOACCESSCONTROL` | **`no`** | Der Standardwert muss deaktiviert werden. Die Zugriffskontrolle muss über einen **davor geschalteten Reverse Proxy** erfolgen. |
| `NOMINATIM_LOOKUP_MAX_COUNT` | **Max. 50** | Begrenzt die Last pro Einzelanfrage. |

---

## 2. Betriebs- und Performance-Anforderungen (Galera/MaxScale)

### 2.1. MaxScale Anbindung und Timeout-Management

Da MaxScale als Proxy verwendet wird, ist die Stabilität der Verbindung kritisch.

| Config-Variable | Standardvorgabe | Funktion/Erläuterung |
| :--- | :--- | :--- |
| `NOMINATIM_API_POOL_SIZE` | **Max. 10** | Die Pool-Größe muss auf die Limits abgestimmt sein, die der **MaxScale-Service** und der dahinterliegende **Galera Cluster** pro Verbindung zulassen. |
| `NOMINATIM_QUERY_TIMEOUT` | **Max. 10s** | Ein strikter Timeout ist wichtig, da Galera-Cluster unter Last oder bei **Split-Brain-Szenarien** unvorhergesehene Latenzen aufweisen können. |
| `NOMINATIM_REQUEST_TIMEOUT` | **Max. 60s** | Schließt langlaufende Suchanfragen sanft ab. |
| **PostgreSQL Settings** | **Minimal** | Aufgrund der Verwendung von MaxScale und MariaDB Galera sind die offiziellen PostgreSQL Tuning-Parameter für Nominatim (wie `shared_buffers`, etc.) **nicht direkt anwendbar**. Die MariaDB Galera Konfiguration muss separat nach BWI-Standards erfolgen. |

### 2.2. Import-Integrität und Wartung

Die Importprozesse müssen unter Berücksichtigung der Galera-Architektur erfolgen.

| Config-Variable | Standardvorgabe | Funktion/Erläuterung |
| :--- | :--- | :--- |
| `NOMINATIM_FLATNODE_FILE` | **Pfad muss definiert werden** | Für alle Datenmengen muss der Pfad persistent sein, da die Datei für alle Update-Prozesse zwingend erforderlich ist. |
| `NOMINATIM_TOKENIZER` | **`icu`** (Standard) | **Achtung:** Kann nach dem Import **nicht mehr geändert werden**. |

---

## 3. Log-Anforderungen

| Config-Variable | Standardvorgabe | Funktion/Erläuterung |
| :--- | :--- | :--- |
| `NOMINATIM_LOG_FILE` | **Leer lassen** | Das Logging muss über `stdout`/`stderr` erfolgen. |
| `NOMINATIM_DEBUG_SQL` | **`no`** | Muss im Produktivbetrieb **deaktiviert** sein. |

Möchten Sie, dass ich Ihnen einen **Strukturvorschlag** für die **Vault Policy** erstelle, die der Nominatim-Container zum Abrufen seiner Secrets benötigen würde?
