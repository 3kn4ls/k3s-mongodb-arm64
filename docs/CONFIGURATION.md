# Configuración Avanzada

Guía completa de configuración avanzada para MongoDB en K3s.

## Tabla de Contenidos

1. [Configuración de MongoDB](#configuración-de-mongodb)
2. [Optimización de Rendimiento](#optimización-de-rendimiento)
3. [Seguridad](#seguridad)
4. [Alta Disponibilidad](#alta-disponibilidad)
5. [Monitoreo y Logging](#monitoreo-y-logging)
6. [Configuración de Red](#configuración-de-red)

## Configuración de MongoDB

### Parámetros del ConfigMap

El archivo `k8s/mongodb/configmap.yaml` contiene la configuración principal de MongoDB.

#### Configuración de Red

```yaml
net:
  port: 27017
  bindIp: 0.0.0.0  # Escuchar en todas las interfaces
  maxIncomingConnections: 100  # Ajustar según necesidad
```

**Recomendaciones:**
- Para producción, aumentar `maxIncomingConnections` si tienes muchos clientes
- Considerar usar `bindIp: 127.0.0.1,10.0.0.1` para limitar acceso

#### Configuración de Storage

```yaml
storage:
  dbPath: /data/db
  journal:
    enabled: true  # Importante para durabilidad
  engine: wiredTiger
  wiredTiger:
    engineConfig:
      cacheSizeGB: 0.5  # Ajustar según RAM disponible
      journalCompressor: snappy
    collectionConfig:
      blockCompressor: snappy
```

**Ajuste de Cache:**

Para Raspberry Pi 5 con diferentes configuraciones de RAM:

```yaml
# 4GB RAM total
cacheSizeGB: 0.25

# 8GB RAM total
cacheSizeGB: 0.5

# 16GB RAM total (si usas un modelo con expansión)
cacheSizeGB: 1.0
```

**Fórmula:** Cache = (RAM_total - 1GB) * 0.5

#### Configuración de Seguridad

```yaml
security:
  authorization: enabled
```

Para habilitar TLS/SSL (avanzado):

```yaml
security:
  authorization: enabled
  tls:
    mode: requireTLS
    certificateKeyFile: /etc/ssl/mongodb/mongodb.pem
    CAFile: /etc/ssl/mongodb/ca.pem
```

#### Configuración de Logging

```yaml
systemLog:
  destination: file
  path: /data/db/mongod.log
  logAppend: true
  verbosity: 0  # 0=info, 1=debug, 2=detailed
```

Para desarrollo, aumentar verbosity:

```yaml
systemLog:
  verbosity: 2
  component:
    query:
      verbosity: 2
    write:
      verbosity: 2
```

### Aplicar cambios de configuración

```bash
# Editar ConfigMap
nano k8s/mongodb/configmap.yaml

# Aplicar cambios
kubectl apply -f k8s/mongodb/configmap.yaml

# Reiniciar MongoDB para aplicar
kubectl rollout restart statefulset mongodb -n mongodb

# Verificar que se aplicó
kubectl exec mongodb-0 -n mongodb -- cat /etc/mongo/mongod.conf
```

## Optimización de Rendimiento

### Recursos del Pod

Editar `k8s/mongodb/statefulset.yaml`:

```yaml
resources:
  requests:
    memory: "512Mi"   # Mínimo garantizado
    cpu: "500m"       # 0.5 CPUs
  limits:
    memory: "2Gi"     # Máximo permitido
    cpu: "2000m"      # 2 CPUs
```

**Perfiles recomendados:**

**Desarrollo/Testing:**
```yaml
requests:
  memory: "256Mi"
  cpu: "250m"
limits:
  memory: "1Gi"
  cpu: "1000m"
```

**Producción ligera:**
```yaml
requests:
  memory: "512Mi"
  cpu: "500m"
limits:
  memory: "2Gi"
  cpu: "2000m"
```

**Producción intensiva:**
```yaml
requests:
  memory: "1Gi"
  cpu: "1000m"
limits:
  memory: "3Gi"
  cpu: "3000m"
```

### Índices

Los índices mejoran significativamente el rendimiento de consultas.

```javascript
// Conectar a MongoDB
kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p

// Cambiar a tu base de datos
use myapp

// Crear índice simple
db.users.createIndex({ email: 1 })

// Crear índice compuesto
db.orders.createIndex({ userId: 1, createdAt: -1 })

// Crear índice único
db.users.createIndex({ username: 1 }, { unique: true })

// Crear índice de texto para búsqueda
db.articles.createIndex({ title: "text", content: "text" })

// Ver índices existentes
db.users.getIndexes()

// Analizar uso de índices
db.users.find({ email: "test@example.com" }).explain("executionStats")
```

### Profiling

Habilitar profiling para identificar consultas lentas:

```javascript
// Nivel 0: Off
// Nivel 1: Solo operaciones lentas
// Nivel 2: Todas las operaciones

// Habilitar profiling de operaciones lentas (>100ms)
db.setProfilingLevel(1, { slowms: 100 })

// Ver operaciones lentas
db.system.profile.find().limit(10).sort({ ts: -1 }).pretty()

// Análisis de operaciones más lentas
db.system.profile.find({ millis: { $gt: 100 } }).sort({ millis: -1 })
```

### Compactación

Recuperar espacio en disco:

```javascript
// Compactar una colección
db.runCommand({ compact: 'mycollection' })

// Compactar con force
db.runCommand({ compact: 'mycollection', force: true })
```

**Nota:** La compactación bloquea la colección temporalmente.

### Optimización del Sistema Operativo

En la Raspberry Pi:

```bash
# Deshabilitar Transparent Huge Pages
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag

# Hacer permanente
sudo nano /etc/rc.local
# Agregar antes de exit 0:
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# Ajustar swappiness
sudo sysctl vm.swappiness=10
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf

# Aumentar file descriptors
sudo nano /etc/security/limits.conf
# Agregar:
* soft nofile 64000
* hard nofile 64000
```

## Seguridad

### Usuarios y Roles

#### Crear usuarios con permisos específicos

```javascript
// Conectar como admin
kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p

// Usuario de solo lectura
use myapp
db.createUser({
  user: "readonly",
  pwd: "secure-password",
  roles: [{ role: "read", db: "myapp" }]
})

// Usuario de lectura/escritura
db.createUser({
  user: "appuser",
  pwd: "secure-password",
  roles: [{ role: "readWrite", db: "myapp" }]
})

// Usuario con permisos de backup
use admin
db.createUser({
  user: "backup",
  pwd: "secure-password",
  roles: ["backup", "restore"]
})

// Listar usuarios
db.getUsers()

// Modificar roles de usuario
db.updateUser("appuser", {
  roles: [
    { role: "readWrite", db: "myapp" },
    { role: "read", db: "analytics" }
  ]
})
```

#### Roles personalizados

```javascript
use admin
db.createRole({
  role: "customAppRole",
  privileges: [
    {
      resource: { db: "myapp", collection: "" },
      actions: ["find", "insert", "update"]
    }
  ],
  roles: []
})
```

### Cifrado TLS/SSL

#### 1. Generar certificados

```bash
# Crear directorio para certificados
mkdir -p ~/mongodb-certs
cd ~/mongodb-certs

# Generar CA
openssl genrsa -out ca-key.pem 4096
openssl req -new -x509 -days 3650 -key ca-key.pem -out ca.pem -subj "/CN=MongoDB-CA"

# Generar certificado del servidor
openssl genrsa -out mongodb-key.pem 4096
openssl req -new -key mongodb-key.pem -out mongodb.csr -subj "/CN=mongodb-service.mongodb.svc.cluster.local"
openssl x509 -req -in mongodb.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out mongodb-cert.pem -days 365

# Combinar certificado y clave
cat mongodb-key.pem mongodb-cert.pem > mongodb.pem
```

#### 2. Crear Secret con certificados

```bash
kubectl create secret generic mongodb-tls \
  --from-file=mongodb.pem=mongodb.pem \
  --from-file=ca.pem=ca.pem \
  -n mongodb
```

#### 3. Actualizar StatefulSet

Agregar volumen y volumeMount en `k8s/mongodb/statefulset.yaml`:

```yaml
volumeMounts:
- name: mongodb-tls
  mountPath: /etc/ssl/mongodb
  readOnly: true

volumes:
- name: mongodb-tls
  secret:
    secretName: mongodb-tls
```

#### 4. Actualizar ConfigMap

```yaml
security:
  authorization: enabled
  tls:
    mode: requireTLS
    certificateKeyFile: /etc/ssl/mongodb/mongodb.pem
    CAFile: /etc/ssl/mongodb/ca.pem
```

### Network Policies

Limitar acceso de red a MongoDB:

```yaml
# k8s/mongodb/networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: mongodb-netpol
  namespace: mongodb
spec:
  podSelector:
    matchLabels:
      app: mongodb
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: my-app-namespace
    ports:
    - protocol: TCP
      port: 27017
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 53  # DNS
```

## Alta Disponibilidad

### Replica Set (Múltiples nodos)

Para configurar un replica set de 3 nodos:

#### 1. Actualizar StatefulSet

```yaml
# k8s/mongodb/statefulset.yaml
spec:
  replicas: 3  # Cambiar de 1 a 3
```

#### 2. Actualizar ConfigMap

```yaml
replication:
  replSetName: rs0
```

#### 3. Inicializar Replica Set

```bash
# Aplicar cambios
kubectl apply -f k8s/mongodb/statefulset.yaml

# Esperar a que todos los pods estén listos
kubectl get pods -n mongodb -w

# Conectar al primer pod
kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p

# Inicializar replica set
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongodb-0.mongodb-service.mongodb.svc.cluster.local:27017" },
    { _id: 1, host: "mongodb-1.mongodb-service.mongodb.svc.cluster.local:27017" },
    { _id: 2, host: "mongodb-2.mongodb-service.mongodb.svc.cluster.local:27017" }
  ]
})

// Verificar estado
rs.status()
```

**Nota:** Para Raspberry Pi, 3 nodos puede ser excesivo. Considerar 1 primario + 1 secundario.

### PodDisruptionBudget

Proteger contra interrupciones:

```yaml
# k8s/mongodb/pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: mongodb-pdb
  namespace: mongodb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: mongodb
```

## Monitoreo y Logging

### Habilitar MongoDB Exporter para Prometheus

```yaml
# k8s/mongodb/exporter.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb-exporter
  namespace: mongodb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb-exporter
  template:
    metadata:
      labels:
        app: mongodb-exporter
    spec:
      containers:
      - name: mongodb-exporter
        image: percona/mongodb_exporter:0.40
        args:
        - --mongodb.uri=mongodb://admin:PASSWORD@mongodb-service:27017
        - --collect-all
        ports:
        - containerPort: 9216
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb-exporter
  namespace: mongodb
spec:
  ports:
  - port: 9216
  selector:
    app: mongodb-exporter
```

### Configurar Log Rotation

```javascript
// Dentro de MongoDB
db.adminCommand({ logRotate: 1 })
```

Automatizar con CronJob de Kubernetes:

```yaml
# k8s/mongodb/log-rotation-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mongodb-log-rotation
  namespace: mongodb
spec:
  schedule: "0 0 * * *"  # Diario a medianoche
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: log-rotate
            image: mongo:7.0
            command:
            - mongosh
            - mongodb://admin:PASSWORD@mongodb-service:27017
            - --eval
            - "db.adminCommand({ logRotate: 1 })"
          restartPolicy: OnFailure
```

## Configuración de Red

### Cambiar Puerto Externo

Editar `k8s/mongodb/service.yaml`:

```yaml
spec:
  type: NodePort
  ports:
    - port: 27017
      targetPort: 27017
      nodePort: 32017  # Cambiar el puerto (rango 30000-32767)
```

### Usar LoadBalancer (requiere MetalLB)

#### 1. Instalar MetalLB

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
```

#### 2. Configurar pool de IPs

```yaml
# metallb-config.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.200-192.168.1.210
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
```

#### 3. Cambiar Service a LoadBalancer

```yaml
spec:
  type: LoadBalancer
```

### Configurar Ingress (para aplicaciones web)

Si tienes una aplicación web que conecta a MongoDB:

```yaml
# k8s/mongodb/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: mongodb
spec:
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-service
            port:
              number: 80
```

## Aplicar Configuraciones

Después de hacer cambios:

```bash
# Aplicar todos los manifiestos
kubectl apply -f k8s/mongodb/

# Reiniciar para aplicar cambios
kubectl rollout restart statefulset mongodb -n mongodb

# Verificar estado
kubectl rollout status statefulset mongodb -n mongodb
```
