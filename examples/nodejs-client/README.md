# Ejemplo de Cliente Node.js para MongoDB

Este ejemplo muestra cómo conectarse a MongoDB en K3s usando Node.js.

## Requisitos

- Node.js 14 o superior
- npm o yarn

## Instalación

```bash
# Instalar dependencias
npm install

# O con yarn
yarn install
```

## Configuración

Configurar las variables de entorno:

```bash
# Para conexión externa (desde fuera del cluster)
export MONGO_HOST=192.168.1.100  # IP de tu Raspberry Pi
export MONGO_PORT=30017
export MONGO_USER=admin
export MONGO_PASS=tu-password
export MONGO_DB=myapp
```

O crear un archivo `.env`:

```env
MONGO_HOST=192.168.1.100
MONGO_PORT=30017
MONGO_USER=admin
MONGO_PASS=tu-password
MONGO_DB=myapp
```

## Uso

```bash
# Ejecutar
npm start

# O en modo desarrollo (con auto-reload)
npm run dev
```

## Funcionalidades

El script de ejemplo demuestra:

1. **Conexión a MongoDB**
   - Manejo de errores de conexión
   - Verificación de conectividad

2. **Operaciones CRUD**
   - Create: Insertar documentos
   - Read: Consultar con filtros
   - Update: Actualizar documentos
   - Delete: Eliminar documentos

3. **Índices**
   - Crear índices únicos
   - Optimizar búsquedas

4. **Estadísticas**
   - Contar documentos
   - Ver tamaño de base de datos
   - Listar colecciones

## Uso en tu Aplicación

```javascript
const { MongoClient } = require('mongodb');

// Conectar
const client = new MongoClient('mongodb://admin:password@192.168.1.100:30017');
await client.connect();

const db = client.db('myapp');

// Insertar
await db.collection('users').insertOne({
  name: 'Test',
  email: 'test@example.com'
});

// Consultar
const user = await db.collection('users').findOne({
  email: 'test@example.com'
});

// Actualizar
await db.collection('users').updateOne(
  { email: 'test@example.com' },
  { $set: { name: 'Updated Name' } }
);

// Eliminar
await db.collection('users').deleteOne({
  email: 'test@example.com'
});

// Cerrar conexión
await client.close();
```

## Conexión desde Kubernetes

Si tu aplicación Node.js corre dentro del cluster K3s:

```javascript
const CONNECTION_STRING = 'mongodb://admin:password@mongodb-service.mongodb.svc.cluster.local:27017';
```

## Recursos

- [MongoDB Node.js Driver Documentation](https://www.mongodb.com/docs/drivers/node/)
- [MongoDB Node.js Quick Start](https://www.mongodb.com/docs/drivers/node/current/quick-start/)
