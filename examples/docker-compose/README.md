# Ejemplo con Docker Compose

Este ejemplo muestra cómo usar Docker Compose para desarrollar aplicaciones que conectan a MongoDB.

## Configuraciones Disponibles

### 1. MongoDB Local (para desarrollo)

Usa un contenedor MongoDB local para desarrollo:

```bash
docker-compose up -d
```

Esto levanta:
- **mongodb-local**: MongoDB corriendo localmente
- **mongo-express**: UI web para administrar MongoDB (http://localhost:8081)
- **app**: Tu aplicación (opcional)

### 2. Conectar a MongoDB en K3s

Para conectar a tu MongoDB en K3s, edita `docker-compose.yml`:

```yaml
services:
  app:
    environment:
      MONGO_HOST: 192.168.1.100  # IP de tu Raspberry Pi
      MONGO_PORT: 30017
      MONGO_USER: admin
      MONGO_PASS: tu-password
```

Y comenta el servicio `mongodb-local`:

```yaml
# mongodb-local:
#   image: mongo:7.0
#   ...
```

## Uso

### Iniciar servicios

```bash
# Iniciar todos los servicios
docker-compose up -d

# Ver logs
docker-compose logs -f

# Ver logs de un servicio específico
docker-compose logs -f app
```

### Acceder a MongoDB

**Usando Mongo Express (UI Web):**

1. Abrir navegador: http://localhost:8081
2. Usuario: `admin`, Password: `pass`

**Usando mongosh:**

```bash
# MongoDB local
docker-compose exec mongodb-local mongosh -u admin -p changeme

# MongoDB en K3s (desde tu máquina)
mongosh "mongodb://admin:PASSWORD@192.168.1.100:30017"
```

### Detener servicios

```bash
# Detener servicios
docker-compose down

# Detener y eliminar volúmenes (CUIDADO: borra datos)
docker-compose down -v
```

## Desarrollo de tu Aplicación

### 1. Crear tu aplicación

Crea tu aplicación en el mismo directorio:

```javascript
// app.js
const { MongoClient } = require('mongodb');

const MONGO_HOST = process.env.MONGO_HOST || 'mongodb-local';
const MONGO_PORT = process.env.MONGO_PORT || '27017';
const MONGO_USER = process.env.MONGO_USER || 'admin';
const MONGO_PASS = process.env.MONGO_PASS || 'changeme';

const uri = `mongodb://${MONGO_USER}:${MONGO_PASS}@${MONGO_HOST}:${MONGO_PORT}`;

async function main() {
  const client = new MongoClient(uri);

  try {
    await client.connect();
    console.log('Conectado a MongoDB');

    const db = client.db('myapp');
    // Tu lógica aquí...

  } finally {
    await client.close();
  }
}

main().catch(console.error);
```

### 2. Actualizar package.json

```json
{
  "name": "my-mongodb-app",
  "version": "1.0.0",
  "dependencies": {
    "mongodb": "^6.3.0",
    "express": "^4.18.2"
  }
}
```

### 3. Reconstruir y ejecutar

```bash
# Reconstruir la imagen
docker-compose build app

# Ejecutar
docker-compose up -d app

# Ver logs
docker-compose logs -f app
```

## Scripts Útiles

### Backup desde contenedor

```bash
# Backup de MongoDB local
docker-compose exec mongodb-local mongodump \
  --username admin \
  --password changeme \
  --authenticationDatabase admin \
  --out /tmp/backup

# Copiar backup a local
docker cp mongodb-local:/tmp/backup ./mongodb-backup-$(date +%Y%m%d)
```

### Restaurar

```bash
# Copiar backup al contenedor
docker cp ./mongodb-backup-20240115 mongodb-local:/tmp/restore

# Restaurar
docker-compose exec mongodb-local mongorestore \
  --username admin \
  --password changeme \
  --authenticationDatabase admin \
  /tmp/restore
```

## Cambiar entre Local y K3s

### Usar MongoDB Local

```yaml
# docker-compose.yml
services:
  app:
    environment:
      MONGO_HOST: mongodb-local
      MONGO_PORT: 27017
    depends_on:
      - mongodb-local
```

### Usar MongoDB en K3s

```yaml
# docker-compose.yml
services:
  app:
    environment:
      MONGO_HOST: 192.168.1.100  # IP de Raspberry Pi
      MONGO_PORT: 30017
    # Comentar depends_on
    # depends_on:
    #   - mongodb-local
```

## Archivo init-mongo.js

Puedes crear un script de inicialización:

```javascript
// init-mongo.js
db = db.getSiblingDB('myapp');

db.createCollection('users');
db.createCollection('products');

db.users.insertMany([
  { name: 'Admin', email: 'admin@example.com', role: 'admin' },
  { name: 'User', email: 'user@example.com', role: 'user' }
]);

print('Base de datos inicializada');
```

Este script se ejecuta automáticamente al crear el contenedor MongoDB.

## Problemas Comunes

### Puerto ya en uso

Si el puerto 27017 ya está en uso:

```yaml
# Cambiar el puerto host
ports:
  - "27018:27017"  # Usar 27018 en lugar de 27017
```

### Permisos en volúmenes

Si tienes problemas de permisos:

```bash
# Limpiar volúmenes
docker-compose down -v

# Recrear
docker-compose up -d
```

### No puede conectar a MongoDB en K3s

1. Verificar que MongoDB está corriendo:
```bash
kubectl get pods -n mongodb
```

2. Verificar conectividad de red:
```bash
nc -zv 192.168.1.100 30017
```

3. Verificar credenciales en el secret de K3s

## Recursos

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [MongoDB Docker Image](https://hub.docker.com/_/mongo)
- [Mongo Express](https://github.com/mongo-express/mongo-express)
