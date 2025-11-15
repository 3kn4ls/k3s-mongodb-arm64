# Ejemplos de Uso

Esta carpeta contiene ejemplos de cómo conectarse y usar MongoDB en K3s desde diferentes lenguajes y entornos.

## Ejemplos Disponibles

### 1. Python Client

Cliente Python usando PyMongo.

**Características:**
- Conexión a MongoDB
- Operaciones CRUD completas
- Manejo de índices
- Estadísticas y monitoreo

**Uso:**
```bash
cd python-client
pip install -r requirements.txt
python app.py
```

Ver [python-client/README.md](python-client/README.md) para más detalles.

### 2. Node.js Client

Cliente Node.js usando el driver oficial de MongoDB.

**Características:**
- Conexión async/await
- Operaciones CRUD
- Manejo de promesas
- Estadísticas de base de datos

**Uso:**
```bash
cd nodejs-client
npm install
npm start
```

Ver [nodejs-client/README.md](nodejs-client/README.md) para más detalles.

### 3. Docker Compose

Configuración de Docker Compose para desarrollo local.

**Características:**
- MongoDB local para desarrollo
- Mongo Express (UI web)
- Fácil cambio entre MongoDB local y K3s

**Uso:**
```bash
cd docker-compose
docker-compose up -d
```

Ver [docker-compose/README.md](docker-compose/README.md) para más detalles.

## Configuración General

Todos los ejemplos requieren configurar las siguientes variables de entorno:

```bash
export MONGO_HOST=192.168.1.100  # IP de tu Raspberry Pi
export MONGO_PORT=30017          # Puerto NodePort de K3s
export MONGO_USER=admin           # Usuario de MongoDB
export MONGO_PASS=tu-password     # Contraseña de MongoDB
export MONGO_DB=myapp             # Base de datos a usar
```

### Obtener Credenciales

Para obtener las credenciales de tu MongoDB en K3s:

```bash
# Usuario
kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.username}' | base64 -d

# Contraseña
kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.password}' | base64 -d
```

### Obtener IP del Cluster

```bash
# IP del nodo
kubectl get nodes -o wide

# O desde la Raspberry Pi
hostname -I | awk '{print $1}'
```

## Connection Strings

### Desde fuera del cluster K3s

```
mongodb://admin:PASSWORD@192.168.1.100:30017
```

### Desde dentro del cluster K3s

```
mongodb://admin:PASSWORD@mongodb-service.mongodb.svc.cluster.local:27017
```

## Otros Lenguajes

### Go

```go
package main

import (
    "context"
    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

func main() {
    clientOptions := options.Client().ApplyURI(
        "mongodb://admin:password@192.168.1.100:30017",
    )

    client, err := mongo.Connect(context.TODO(), clientOptions)
    if err != nil {
        panic(err)
    }
    defer client.Disconnect(context.TODO())

    // Usar client...
}
```

### Java (Spring Boot)

```yaml
# application.yml
spring:
  data:
    mongodb:
      uri: mongodb://admin:password@192.168.1.100:30017/myapp
      authentication-database: admin
```

### PHP

```php
<?php
$manager = new MongoDB\Driver\Manager(
    "mongodb://admin:password@192.168.1.100:30017"
);

$bulk = new MongoDB\Driver\BulkWrite;
$bulk->insert(['name' => 'Test']);

$manager->executeBulkWrite('myapp.users', $bulk);
?>
```

### Rust

```rust
use mongodb::{Client, options::ClientOptions};

#[tokio::main]
async fn main() {
    let client_options = ClientOptions::parse(
        "mongodb://admin:password@192.168.1.100:30017"
    ).await.unwrap();

    let client = Client::with_options(client_options).unwrap();

    // Usar client...
}
```

## Herramientas GUI

### MongoDB Compass

1. Descargar [MongoDB Compass](https://www.mongodb.com/products/compass)
2. Conectar usando:
   - Host: `192.168.1.100`
   - Port: `30017`
   - Authentication: Username/Password
   - Username: `admin`
   - Password: tu-password

### Studio 3T

1. Descargar [Studio 3T](https://studio3t.com/)
2. Crear nueva conexión
3. Usar connection string: `mongodb://admin:password@192.168.1.100:30017`

## Testing de Conexión

### Usando mongosh

```bash
# Instalar mongosh
# Ubuntu/Debian:
wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update
sudo apt-get install -y mongodb-mongosh

# Conectar
mongosh "mongodb://admin:PASSWORD@192.168.1.100:30017"
```

### Usando netcat

```bash
# Verificar que el puerto está abierto
nc -zv 192.168.1.100 30017
```

### Usando telnet

```bash
telnet 192.168.1.100 30017
```

## Solución de Problemas

### No puedo conectar

1. Verificar que MongoDB está corriendo:
```bash
kubectl get pods -n mongodb
```

2. Verificar servicio:
```bash
kubectl get svc -n mongodb
```

3. Verificar puerto:
```bash
kubectl get svc mongodb-external -n mongodb -o jsonpath='{.spec.ports[0].nodePort}'
```

4. Probar desde el pod:
```bash
kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p
```

### Error de autenticación

1. Verificar credenciales:
```bash
kubectl get secret mongodb-secret -n mongodb -o yaml
```

2. Las credenciales están en base64, decodificar:
```bash
echo "ENCODED_PASSWORD" | base64 -d
```

### Timeout de conexión

1. Verificar firewall en Raspberry Pi
2. Verificar que el NodePort está accesible
3. Probar conectividad de red

## Contribuir

¿Tienes un ejemplo en otro lenguaje? ¡Contribuye!

1. Crea una carpeta para tu lenguaje
2. Incluye un ejemplo funcional
3. Añade un README.md explicativo
4. Crea un Pull Request

Ver [CONTRIBUTING.md](../CONTRIBUTING.md) para más detalles.
