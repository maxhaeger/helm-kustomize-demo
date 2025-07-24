# Kubernetes, Helm & ArgoCD Workshop

## Architektur

#####  Docker Grundlagen

**Das Problem ohne Container:** "Auf meinem Rechner läuft's" - klassisches Entwicklerproblem. Unterschiedliche Betriebssysteme, Library-Versionen, Konfigurationen führen zu inkonsistentem Verhalten.

**Docker-Lösung:** Container packen Anwendung + alle Dependencies in eine isolierte, portable Unit. Ein Container läuft identisch auf Development-Laptop, Test-Server und Production-Cluster.

**Container vs. VM:**

- **Virtual Machine:** Komplettes Betriebssystem pro Anwendung (mehrere GB)
- **Container:** Teilt Kernel des Host-OS, nur Application Layer isoliert (wenige MB)

**Docker-Komponenten:**

- **Image:** Read-only Template (wie ISO-Datei)
- **Container:** Laufende Instanz eines Images
- **Dockerfile:** Build-Instructions für Images
- **Registry:** Zentrale Image-Verteilung (Docker Hub, private Registries)

**Beispiel:**
`docker run -d --name web -p 8080:80 nginx`

#### Kubernetes Grundlagen

**Das Problem mit einzelnen Containern:** Docker kann einzelne Container starten, aber was passiert bei Ausfall? Wie skaliert man auf 100 Container? Wie kommunizieren sie miteinander? Wie verteilt man Updates?

**Kubernetes-Lösung:** Deklaratives System für Container-Management. Ihr beschreibt den gewünschten Zustand (desired state), Kubernetes sorgt dafür, dass er erreicht und gehalten wird.

**Core-Konzepte:**

**Pod:** Kleinste deploybare Einheit

- Ein oder mehrere Container die zusammengehören
- Teilen sich IP-Adresse und Storage
- Werden gemeinsam geplant und verwaltet

**Deployment:** Verwaltet Pod-Replikas

```yaml
spec:
  replicas: 3  # Kubernetes sorgt dafür, dass immer 3 Pods laufen
```

**Service:** Stable Netzwerk-Endpoint für Pods
- Pods kommen und gehen, Services bleiben
- Load-Balancing zwischen Pod-Instanzen
- DNS-Namen für Service Discovery

**Namespace:** Logische Cluster-Trennung
- Isolation verschiedener Anwendungen/Teams
- Resource-Quotas und RBAC pro Namespace

**Das Kubernetes Control Plane:**
- **API Server:** Zentrale REST-API, alle Anfragen laufen hier durch
- **etcd:** Distributed Key-Value Store für Cluster-State
- **Scheduler:** Entscheidet auf welchen Nodes Pods laufen
- **Controller Manager:** Überwacht desired vs actual state

**Worker Nodes:**
- **kubelet:** Agent auf jedem Node, startet/stoppt Container
- **kube-proxy:** Netzwerk-Proxy für Services
- **Container Runtime:** Docker/containerd zum Container-Management

**Beispiel aus unserem Setup:**
```yaml
# Deployment beschreibt WAS laufen soll
replicas: 3
image: nginx:1.14.2

# Service beschreibt WIE darauf zugegriffen wird  
type: ClusterIP
port: 80

# Ingress beschreibt WIE Traffic von außen reinkommt
path: /
backend: nginx-service
```

**Kubernetes Reconciliation Loop:**

1. Gewünschter Zustand in etcd gespeichert
2. Controller überwachen aktuellen Zustand
3. Bei Abweichung werden Aktionen ausgeführt
4. Pod crashed? Neuer wird gestartet
5. Node fällt aus? Pods werden auf andere Nodes verteilt

**Warum Kubernetes für euch wichtig ist:**

- **Automatisierung:** Keine manuellen Server-Eingriffe mehr
- **Skalierung:** Von 1 auf 1000 Instanzen per kubectl-Befehl/k9s/ArgoCD
- **Self-Healing:** Kaputte Container werden automatisch ersetzt
- **Rolling Updates:** Neue Versionen ohne Downtime
- **Resource-Management:** 
- CPU/RAM-Limits pro Container
- Container-Orchestrierung und -Management
- Automatische Skalierung, Health Checks, Service Discovery
- Deklarative Konfiguration über YAML-Manifeste

**Helm**
- Paketmanager für Kubernetes
- Template-Engine für wiederverwendbare Deployments
- Versionierung und Rollback-Funktionalität

**ArgoCD**
- GitOps-Controller für kontinuierliche Synchronisation
- Überwacht Git-Repository und wendet Änderungen automatisch an
- Declarative State Management

## Praktische Umsetzung

### Cluster Setup

```bash
task build
```

Erstellt k3d-Cluster mit LoadBalancer-Konfiguration auf Port 8080.

### Anwendungsstruktur analysieren

**Helm Chart Structure:**

```
nginx-demo/
├── Chart.yaml          # Chart-Metadaten
├── values.yaml         # Konfigurationswerte
└── templates/
    ├── deployment.yaml # Pod-Spezifikation
    ├── service.yaml    # Service-Definition
    ├── ingress.yaml    # Ingress-Controller
    └── cm.yaml         # ConfigMap für HTML-Content
```

**Key Components:**

- Deployment: 3 Nginx-Replicas mit ConfigMap-Mount
- Service: ClusterIP für interne Kommunikation
- Ingress: HTTP-Routing ohne SSL-Redirect
- ConfigMap: Static HTML Content

### Deployment ausführen

```bash
task deploy
```

Installiert:

- Nginx-Demo via Helm
- ArgoCD in eigenem Namespace
- LoadBalancer-Service für ArgoCD

### ArgoCD Konfiguration

```bash
task argocd
```

Registriert Application mit:

- Source: GitHub Repository
- Target: Default Namespace
- Sync Policy: Manual (prune/selfHeal disabled)

### Zugriff und Monitoring

**ArgoCD UI:**

```bash
task publish  # Port-Forward auf 8081
```

**Admin-Password abrufen:**

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Troubleshooting-Strategien

### Pod-Debugging

```bash
# Status und Events
kubectl get pods -o wide
kubectl describe pod <pod-name>

# Logs analysieren
kubectl logs <pod-name> --previous
kubectl logs <pod-name> -f

# Container-Zugriff
kubectl exec -it <pod-name> -- /bin/bash
```

### Service-Connectivity

```bash
# Service Endpoints prüfen
kubectl get endpoints
kubectl describe svc <service-name>

# Direct Port-Forward Testing
kubectl port-forward pod/<pod-name> 8080:80
```

### ArgoCD-Synchronisation

```bash
# Application Status
kubectl get application -n argocd
kubectl describe application nginx-demo -n argocd

# Manual Sync
argocd app sync nginx-demo
```

### Häufige Fehlerquellen

**ImagePullBackOff:** Registry-Zugriff oder Tag-Probleme **CrashLoopBackOff:** Anwendungsfehler, falsche Health Checks **Pending Pods:** Resource-Constraints oder Scheduling-Probleme **Service Discovery:** Label-Selectors stimmen nicht überein

### Monitoring-Commands

```bash
# Cluster-Ressourcen
kubectl top nodes
kubectl top pods

# Events
kubectl get events --sort-by=.metadata.creationTimestamp

# Ingress-Status
kubectl get ingress -o wide
```

## Erweiterte Konzepte

### GitOps-Workflow

1. Code-Änderung in Git
2. ArgoCD erkennt Drift
3. Automatische Synchronisation
4. Health-Check und Rollback bei Fehlern

### Helm-Templates

- Werte-Interpolation mit `{{ .Values.* }}`
- Bedingte Ressourcen mit `{{ if }}`
- Loops und Funktionen verfügbar

### Skalierung testen

```bash
# Replicas ändern
kubectl scale deployment nginx-deployment --replicas=5

# HPA aktivieren
kubectl autoscale deployment nginx-deployment --cpu-percent=50 --min=1 --max=10
```

## Cleanup

```bash
task clean
```

Entfernt komplette k3d-Cluster-Instanz.
