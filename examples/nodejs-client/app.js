#!/usr/bin/env node

/**
 * Ejemplo de cliente Node.js para conectar a MongoDB en K3s
 * Requiere: npm install mongodb
 */

const { MongoClient } = require('mongodb');

// Configuración de conexión
const MONGO_HOST = process.env.MONGO_HOST || 'localhost';
const MONGO_PORT = process.env.MONGO_PORT || '30017';
const MONGO_USER = process.env.MONGO_USER || 'admin';
const MONGO_PASS = process.env.MONGO_PASS || 'changeme';
const MONGO_DB = process.env.MONGO_DB || 'myapp';

// Connection string
const CONNECTION_STRING = `mongodb://${MONGO_USER}:${MONGO_PASS}@${MONGO_HOST}:${MONGO_PORT}`;

// Cliente MongoDB
let client;

/**
 * Conectar a MongoDB
 */
async function connectToMongoDB() {
  try {
    client = new MongoClient(CONNECTION_STRING, {
      serverSelectionTimeoutMS: 5000
    });

    await client.connect();

    // Verificar conexión
    await client.db('admin').command({ ping: 1 });

    console.log(`✓ Conectado a MongoDB en ${MONGO_HOST}:${MONGO_PORT}`);
    return client;
  } catch (error) {
    console.error(`✗ Error de conexión: ${error.message}`);
    return null;
  }
}

/**
 * Crear datos de ejemplo
 */
async function createSampleData(db) {
  const usersCollection = db.collection('users');

  // Crear índice único en email
  await usersCollection.createIndex({ email: 1 }, { unique: true });

  // Insertar usuarios de ejemplo
  const sampleUsers = [
    {
      name: 'Juan Pérez',
      email: 'juan@example.com',
      age: 30,
      createdAt: new Date()
    },
    {
      name: 'María García',
      email: 'maria@example.com',
      age: 25,
      createdAt: new Date()
    },
    {
      name: 'Carlos López',
      email: 'carlos@example.com',
      age: 35,
      createdAt: new Date()
    }
  ];

  try {
    const result = await usersCollection.insertMany(sampleUsers);
    console.log(`\n✓ Insertados ${result.insertedCount} usuarios`);
    return true;
  } catch (error) {
    console.error(`\n✗ Error insertando usuarios: ${error.message}`);
    return false;
  }
}

/**
 * Consultar datos
 */
async function queryData(db) {
  const usersCollection = db.collection('users');

  console.log('\n=== Todos los usuarios ===');
  const allUsers = await usersCollection.find().toArray();
  allUsers.forEach(user => {
    console.log(`- ${user.name} (${user.email}) - ${user.age} años`);
  });

  console.log('\n=== Usuarios mayores de 30 ===');
  const olderUsers = await usersCollection.find({ age: { $gt: 30 } }).toArray();
  olderUsers.forEach(user => {
    console.log(`- ${user.name} - ${user.age} años`);
  });

  // Contar documentos
  const total = await usersCollection.countDocuments();
  console.log(`\n📊 Total de usuarios: ${total}`);
}

/**
 * Actualizar datos
 */
async function updateData(db) {
  const usersCollection = db.collection('users');

  // Actualizar un usuario
  const result = await usersCollection.updateOne(
    { email: 'juan@example.com' },
    { $set: { age: 31 } }
  );

  if (result.modifiedCount > 0) {
    console.log('\n✓ Usuario actualizado');
  } else {
    console.log('\n- No se actualizó ningún usuario');
  }
}

/**
 * Eliminar datos
 */
async function deleteData(db) {
  const usersCollection = db.collection('users');

  // Eliminar un usuario
  const result = await usersCollection.deleteOne({ email: 'carlos@example.com' });

  if (result.deletedCount > 0) {
    console.log('\n✓ Usuario eliminado');
  } else {
    console.log('\n- No se eliminó ningún usuario');
  }
}

/**
 * Mostrar estadísticas de la base de datos
 */
async function showStats(db) {
  console.log('\n=== Estadísticas de la Base de Datos ===');

  // Listar colecciones
  const collections = await db.listCollections().toArray();
  const collectionNames = collections.map(c => c.name);
  console.log(`\n📁 Colecciones: ${collectionNames.join(', ')}`);

  // Estadísticas por colección
  for (const collectionName of collectionNames) {
    const collection = db.collection(collectionName);
    const count = await collection.countDocuments();
    console.log(`  - ${collectionName}: ${count} documentos`);
  }

  // Estadísticas del servidor
  const stats = await db.stats();
  console.log(`\n💾 Tamaño de la base de datos: ${(stats.dataSize / 1024 / 1024).toFixed(2)} MB`);
  console.log(`📊 Número de objetos: ${stats.objects}`);
}

/**
 * Función principal
 */
async function main() {
  console.log('='.repeat(50));
  console.log('Cliente Node.js - MongoDB en K3s');
  console.log('='.repeat(50));

  // Conectar
  const client = await connectToMongoDB();
  if (!client) {
    return;
  }

  const db = client.db(MONGO_DB);

  try {
    // Crear datos de ejemplo
    console.log('\n--- Creando datos de ejemplo ---');
    await createSampleData(db);

    // Consultar datos
    console.log('\n--- Consultando datos ---');
    await queryData(db);

    // Actualizar datos
    console.log('\n--- Actualizando datos ---');
    await updateData(db);
    await queryData(db);

    // Eliminar datos
    console.log('\n--- Eliminando datos ---');
    await deleteData(db);
    await queryData(db);

    // Mostrar estadísticas
    await showStats(db);

  } catch (error) {
    console.error(`\n✗ Error: ${error.message}`);
  } finally {
    // Cerrar conexión
    await client.close();
    console.log('\n✓ Conexión cerrada');
  }
}

// Ejecutar
main().catch(console.error);
