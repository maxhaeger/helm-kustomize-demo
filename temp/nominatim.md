Absolut. Die letzte Version des Produktstandards ist frei von Emojis und konzentriert sich strikt auf die technischen Anforderungen der K8s/Vault/MariaDB-Umgebung.

---

# BWI Produktstandard: Nominatim Geocoding Service (K8s Edition)

*Version: 2.0 (K8s/Vault/MariaDB Galera Anpassung) | Stand: 2025-12-01 | Geltungsbereich: Alle K8s-Projekte mit Geocoding-Bedarf*

Dieser Standard definiert die **verbindliche Konfiguration** des Nominatim Docker Containers für den Betrieb in einem **Kubernetes-Cluster** unter Verwendung von **HashiCorp Vault** und **MariaDB Galera/MaxScale**.

---

## 1. Sicherheitsrelevante Konfiguration (Muss-Anforderungen)

### 1.1. Secrets- und Credentials-Management (HashiCorp Vault/K8s)

Statische Passwörter sind **untersagt**. Der Nominatim-Pod muss **dynamische Secrets** von Vault über einen K8s-nativen Mechanismus (z.B. Sidecar) beziehen.

| Config-Variable | K8s-Standardvorgabe | Begründung/Hinweis |
| :--- | :--- | :--- |
| **Passwort** in `NOMINATIM_DATABASE_DSN` | **VERBOTEN** | Secrets werden **dynamisch** über den **Vault Agent Sidecar** oder einen **Secrets Injector** bezogen und in das Dateisystem oder als Umgebungsvariable injiziert.  |
| `NOMINATIM_DATABASE_DSN` | **Anbindung an MaxScale Service (K8s)** | Die DSN muss den **Kubernetes Service-Namen** von **MaxScale** als Host referenzieren. Format: `pgsql:dbname=nominatim;host=<MaxScale-Service-Name>;port=<MaxScale-Port>`. |
| `NOMINATIM_DATABASE_WEBUSER` | **Dynamisch generierter User** | Der User muss über das **Vault Database Secret Backend** für MariaDB Galera **dynamisch generiert** werden (**kurzlebige Credentials**). |
| **Container-Privilegien** | **SecurityContext (Non-Root)** | Der Container muss einen **SecurityContext** mit **Non-Root-User** (`runAsNonRoot: true`) und idealerweise **ReadOnlyRootFilesystem** verwenden. |

### 1.2. API-Sicherheit und Netzwerk (K8s Ingress)

| Config-Variable | Standardvorgabe | Begründung/Hinweis |
| :--- | :--- | :--- |
| `NOMINATIM_CORS_NOACCESSCONTROL` | **`no`** | Die Zugriffskontrolle und die **TLS-Terminierung** müssen über den **K8s Ingress/Gateway** erfolgen. CORS-Header dürfen nicht global freigegeben werden. |
| **Exposure** | **K8s Service/Ingress** | Der Nominatim-Container darf **keinen** `NodePort` oder `HostPort` verwenden. Die Freigabe erfolgt ausschließlich über einen **ClusterIP Service** und einen **Ingress-Controller**. |
| `NOMINATIM_LOOKUP_MAX_COUNT` | **Max. 50** | Begrenzt die Last pro Anfrage, ergänzend zu Rate-Limiting-Regeln im Ingress-Layer. |

---

## 2. Betriebs- und Skalierungsanforderungen (K8s Native)

### 2.1. K8s Ressourcen-Definitionen und Health Checks

| K8s-Konzept | Standardvorgabe | Funktion/Erläuterung |
| :--- | :--- | :--- |
| **Ressourcen** | **Requests und Limits** | CPU- und Memory-**Requests** sowie **Limits** müssen im Deployment Manifest gesetzt werden, um die QoS und die Cluster-Stabilität zu gewährleisten. |
| **Liveness Probe** | **HTTP GET** | Ein Liveness Probe auf einen stabilen Endpunkt muss definiert werden, um fehlerhafte Container automatisch neu zu starten. |
| **Readiness Probe** | **HTTP GET (mit DB-Prüfung)** | Ein Readiness Probe muss die **Datenbankverbindung** (über MaxScale) prüfen. Der Pod darf erst Traffic erhalten, wenn er "Ready" ist. |
| **HorizontalPodAutoscaler (HPA)** | **Verbindlich** | Der Dienst muss über einen HPA skalierbar sein (z.B. basierend auf CPU-Auslastung oder QPS-Metriken), um Lastspitzen abzufangen. |

### 2.2. Datenbank und Datenpersistenz

* **Persistenz:** Daten (Flatnode, Datenbank) müssen extern vom Pod-Lebenszyklus gemanagt werden.
    * `NOMINATIM_FLATNODE_FILE`: Der Pfad muss auf einem **Persistent Volume (PV)** und einem **Persistent Volume Claim (PVC)** gemountet werden.
    * **MariaDB Galera:** Muss als separater **StatefulSet** oder als **externer Managed Service** betrieben werden.

### 2.3. Laufzeit und Timeouts

Die Timeouts sind auf die Cluster- und Datenbank-Latenzen abzustimmen.

| Config-Variable | Standardvorgabe | Funktion/Erläuterung |
| :--- | :--- | :--- |
| `NOMINATIM_API_POOL_SIZE` | **Max. 10** | Die Pool-Größe pro Pod muss zu den MaxScale/Galera-Limits passen. |
| `NOMINATIM_QUERY_TIMEOUT` | **Max. 10s** | Ein strikter SQL-Timeout ist zur Abwehr von Galera-Cluster-Instabilitäten notwendig. |
| `NOMINATIM_REPLICATION_MAX_DIFF` | **Max. 50 MB** | Reduziert die RAM-Nutzung während der Updates. Bei integriertem Replikations-Container sind die Limits entsprechend anzupassen. |

---

## 3. Logging und Monitoring

* **Logging-Standard:** `NOMINATIM_LOG_FILE` muss **leer** bleiben. Das Logging erfolgt über **`stdout`/`stderr`** und wird vom **K8s Logging-Agenten** (z.B. Fluentd) aggregiert.
* **Metriken:** Das K8s Monitoring-System (Prometheus/Grafana) muss das Nominatim-Logging-Format parsen, um **Performance-Metriken** (`total_time`, `results_total`) zu extrahieren.
* **Debugging:** `NOMINATIM_DEBUG_SQL=no` ist im Produktivbetrieb **zwingend** zu setzen.

### 4. Erweiterte Performance- und Daten-Konfiguration

Diese Variablen steuern, welche Daten importiert werden und wie Nominatim Anfragen priorisiert.

#### 4.1. Datenumfang und Sprache

Die Steuerung des importierten Datenumfangs ist kritisch, um die Datenbankgröße und die Importzeit zu optimieren.

| Config-Variable | Standardvorgabe | Funktion/Erläuterung |
| :--- | :--- | :--- |
| `NOMINATIM_IMPORT_STYLE` | **`extratags`** | Der zu verwendende Import-Stil. Ein benutzerdefinierter Stil kann über eine **K8s ConfigMap** bereitgestellt und in den Container gemountet werden. |
| `NOMINATIM_LANGUAGES` | **`(leere Liste)`** | **Empfehlung:** Hier eine **komma-separierte Liste** der benötigten Sprachen (z.B. `de,en,fr`) definieren, um die Datenbankgröße und die Importzeit zu reduzieren. Standardmäßig werden alle Sprachvarianten (`name:XX`) in den Index aufgenommen. |
| `NOMINATIM_LIMIT_REINDEXING` | **`yes`** | **Empfohlen:** Stellt sicher, dass das **Reindexing** von Objekten übersprungen wird, wenn die betroffene Fläche zu groß ist. Dies reduziert die Update-Last und schützt vor langen Sperrzeiten der Datenbank. |
| `NOMINATIM_USE_US_TIGER_DATA` | **`no`** | Muss auf **`no`** stehen, wenn keine TIGER-Daten verwendet werden. Eine Änderung erfordert das erneute Ausführen von `nominatim refresh --functions`. |
| `NOMINATIM_WIKIPEDIA_DATA_PATH` | **Projektverzeichnis** | Wenn Wikipedia-Daten verwendet werden, muss dieser Pfad auf ein **Persistent Volume (PV)** zeigen, wo die Daten gespeichert sind. |

#### 4.2. API-Verhalten und Ausgabe

| Config-Variable | Standardvorgabe | Funktion/Erläuterung |
| :--- | :--- | :--- |
| `NOMINATIM_DEFAULT_LANGUAGE` | **`(leere Zeichenkette)`** | Definiert die Fallback-Sprache, wenn keine Sprache über den HTTP `Accept-Languages`-Header angefragt wird. **Empfehlung:** Auf die primäre Abfragesprache (z.B. `de`) setzen, um konsistente Ergebnisse zu gewährleisten. Eine Änderung erfordert `nominatim refresh --website`. |
| `NOMINATIM_OUTPUT_NAMES` | **Standardliste** | Definiert die Reihenfolge, in der verschiedene Namenstags verwendet werden. Anpassung nur nötig, wenn eine **abweichende Priorisierung** von Namensvarianten (z.B. `brand` vor `name`) erforderlich ist. |
| `NOMINATIM_SERVE_LEGACY_URLS` | **`no`** | **Empfehlung:** Auf **`no`** setzen, um unnötige Endpunkte zu vermeiden, wenn keine Abwärtskompatibilität zu `.php`-URLs erforderlich ist. |
| `NOMINATIM_SEARCH_WITHIN_COUNTRIES` | **`no`** | Sollte auf **`yes`** gesetzt werden, wenn die Suche auf Elemente beschränkt werden soll, die sich innerhalb der Ländergrenzen des statischen Country Grids befinden. |

---

### 5. 🛠️ Datenbank-Speicher-Management (Postgres/Tablespaces)

Obwohl MariaDB Galera das Backend ist, bietet Nominatim diese PostgreSQL-bezogenen Variablen an, die bei komplexen Setups (z.B. sehr großen Imports) relevant sein können.

| Config-Variable (Gruppe) | Standardvorgabe | Funktion/Erläuterung |
| :--- | :--- | :--- |
| `NOMINATIM_TABLESPACE_*` | **`(leere Zeichenkette)`** | **Empfehlung:** Leer lassen. Diese Variablen dienen der Verteilung von Datenbank-Objekten auf **separate PostgreSQL Tablespaces**. Im K8s/MariaDB-Kontext sollte die Speicheroptimierung über die MariaDB-Storage-Engine- und Galera-Konfiguration erfolgen. |
| `NOMINATIM_FLATNODE_FILE` | **Pfad zu PV** | Muss für eine optimale Importgeschwindigkeit und für die Funktion der Updates gesetzt werden. |
| `NOMINATIM_REPLICATION_URL` | **Überprüfen** | Muss auf die zugelassene **interne** oder **externe** Replikationsquelle gesetzt werden. Eine Änderung erfordert `nominatim replication --init`. |
