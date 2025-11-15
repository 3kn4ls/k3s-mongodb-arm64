# Acceso a MongoDB desde la Red Interna

## 🔌 Conexión desde la Red Local

MongoDB está expuesto en tu red interna a través de un servicio **NodePort** de Kubernetes.

### Obtener Información de Conexión

Ejecuta estos comandos en tu Raspberry Pi para obtener los datos de conexión:

```bash
# Obtener el puerto NodePort
kubectl get svc mongodb-external -n mongodb -o jsonpath='{.spec.ports[0].nodePort}'

# Obtener usuario
kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.username}' | base64 -d

# Obtener contraseña
kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.password}' | base64 -d
```

### Connection String

Formato general:

```
mongodb://USUARIO:CONTRASEÑA@192.168.1.95:PUERTO
```

Ejemplo (reemplaza con tus credenciales reales):

```
mongodb://admin:tu-contraseña@192.168.1.95:30017
```

## 🧪 Probar la Conexión

### Opción 1: Desde tu PC con mongosh

Si tienes `mongosh` instalado en tu PC local:

```bash
mongosh "mongodb://admin:CONTRASEÑA@192.168.1.95:30017"
```

Una vez conectado, prueba estos comandos:

```javascript
// Ver bases de datos
show dbs

// Crear una base de datos de prueba
use test

// Insertar un documento
db.prueba.insertOne({ mensaje: "¡Conectado desde la red local!" })

// Leer el documento
db.prueba.find()

// Ver estadísticas
db.stats()
```

### Opción 2: Instalar mongosh en tu PC

#### En Ubuntu/Debian:

```bash
wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
sudo apt-get update
sudo apt-get install -y mongodb-mongosh
```

#### En macOS:

```bash
brew install mongosh
```

#### En Windows:

Descarga desde: https://www.mongodb.com/try/download/shell

### Opción 3: Probar con telnet (verificar conectividad)

```bash
# Desde cualquier PC en la red
telnet 192.168.1.95 30017
```

Si se conecta, verás algo así:
```
Trying 192.168.1.95...
Connected to 192.168.1.95.
```

Presiona `Ctrl+]` y luego `quit` para salir.

### Opción 4: Probar con netcat

```bash
nc -zv 192.168.1.95 30017
```

Salida esperada:
```
Connection to 192.168.1.95 30017 port [tcp/*] succeeded!
```

## 📱 Conectar desde Aplicaciones

### Python

```python
from pymongo import MongoClient

# Configuración
MONGO_HOST = "192.168.1.95"
MONGO_PORT = 30017  # Reemplaza con tu puerto NodePort
MONGO_USER = "admin"
MONGO_PASS = "tu-contraseña"

# Conectar
client = MongoClient(
    f"mongodb://{MONGO_USER}:{MONGO_PASS}@{MONGO_HOST}:{MONGO_PORT}"
)

# Probar conexión
db = client.test
db.prueba.insert_one({"mensaje": "Hola desde Python"})
print(db.prueba.find_one())
```

### Node.js

```javascript
const { MongoClient } = require('mongodb');

const uri = "mongodb://admin:tu-contraseña@192.168.1.95:30017";
const client = new MongoClient(uri);

async function conectar() {
  try {
    await client.connect();
    console.log("Conectado a MongoDB");

    const db = client.db('test');
    await db.collection('prueba').insertOne({ mensaje: "Hola desde Node.js" });

    const doc = await db.collection('prueba').findOne();
    console.log(doc);
  } finally {
    await client.close();
  }
}

conectar();
```

### Java (Spring Boot)

```yaml
# application.yml
spring:
  data:
    mongodb:
      host: 192.168.1.95
      port: 30017
      username: admin
      password: tu-contraseña
      database: myapp
      authentication-database: admin
```

### PHP

```php
<?php
$manager = new MongoDB\Driver\Manager(
    "mongodb://admin:tu-contraseña@192.168.1.95:30017"
);

$bulk = new MongoDB\Driver\BulkWrite;
$bulk->insert(['mensaje' => 'Hola desde PHP']);

$manager->executeBulkWrite('test.prueba', $bulk);
?>
```

### Go

```go
package main

import (
    "context"
    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

func main() {
    uri := "mongodb://admin:tu-contraseña@192.168.1.95:30017"
    client, err := mongo.Connect(context.TODO(), options.Client().ApplyURI(uri))
    if err != nil {
        panic(err)
    }
    defer client.Disconnect(context.TODO())

    // Usar el cliente...
}
```

## 🖥️ Herramientas GUI

### MongoDB Compass

1. Descargar: https://www.mongodb.com/try/download/compass
2. Abrir MongoDB Compass
3. Usar este connection string:
   ```
   mongodb://admin:tu-contraseña@192.168.1.95:30017
   ```

### Studio 3T

1. Descargar: https://studio3t.com/download/
2. Crear nueva conexión
3. Configurar:
   - **Server:** 192.168.1.95
   - **Port:** 30017
   - **Authentication:** Username/Password
   - **Username:** admin
   - **Password:** tu-contraseña

### NoSQLBooster

1. Descargar: https://nosqlbooster.com/downloads
2. Nueva conexión
3. Connection String: `mongodb://admin:tu-contraseña@192.168.1.95:30017`

## 🔒 Consideraciones de Seguridad

### 1. Firewall

Asegúrate de que el puerto está accesible solo en tu red local. En la Raspberry Pi:

```bash
# Verificar reglas de firewall (si usas ufw)
sudo ufw status

# Si quieres restringir acceso solo a tu red local (opcional)
sudo ufw allow from 192.168.1.0/24 to any port 30017
```

### 2. Cambiar Contraseña

Si estás usando la contraseña por defecto (`changeme`), cámbiala:

```bash
cd ~/ws/k3s-mongodb-arm64/scripts
./generate-secrets.sh
kubectl apply -f ../k8s/secrets/secret.yaml
kubectl rollout restart statefulset mongodb -n mongodb
```

### 3. VPN (Opcional)

Para acceso desde fuera de tu red local, considera usar:
- WireGuard
- OpenVPN
- Tailscale

**NO** expongas el puerto 30017 directamente a Internet.

## 🔍 Solución de Problemas

### No puedo conectar desde mi PC

1. **Verificar que el servicio está corriendo:**
   ```bash
   kubectl get svc mongodb-external -n mongodb
   ```

2. **Verificar que el pod está en Running:**
   ```bash
   kubectl get pods -n mongodb
   ```

3. **Probar desde la Raspberry Pi:**
   ```bash
   kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p
   ```

4. **Verificar conectividad de red:**
   ```bash
   # Desde tu PC
   ping 192.168.1.95
   nc -zv 192.168.1.95 30017
   ```

5. **Ver logs de MongoDB:**
   ```bash
   kubectl logs mongodb-0 -n mongodb
   ```

### Error de autenticación

Verifica las credenciales:

```bash
kubectl get secret mongodb-secret -n mongodb -o yaml
```

### Puerto bloqueado

Verifica que K3s no tiene restricciones:

```bash
# Ver reglas de iptables
sudo iptables -L -n | grep 30017
```

## 📊 Monitoreo

Para ver información de conexión y estado:

```bash
cd ~/ws/k3s-mongodb-arm64/scripts
./monitor-mongodb.sh
```

## 🔗 URLs de Referencia

- [MongoDB Connection String URI Format](https://www.mongodb.com/docs/manual/reference/connection-string/)
- [MongoDB Drivers](https://www.mongodb.com/docs/drivers/)
- [MongoDB Compass](https://www.mongodb.com/products/compass)

## 📝 Resumen Rápido

```bash
# IP: 192.168.1.95
# Puerto: 30017 (por defecto, verificar con kubectl)
# Usuario: admin (por defecto)
# Contraseña: Obtener con el comando de arriba

# Connection String:
mongodb://admin:CONTRASEÑA@192.168.1.95:30017

# Probar:
mongosh "mongodb://admin:CONTRASEÑA@192.168.1.95:30017"
```
