#!/usr/bin/env python3
"""
Ejemplo de cliente Python para conectar a MongoDB en K3s
Requiere: pip install pymongo
"""

from pymongo import MongoClient
from pymongo.errors import ConnectionFailure, OperationFailure
import os
from datetime import datetime

# Configuración de conexión
MONGO_HOST = os.getenv('MONGO_HOST', 'localhost')
MONGO_PORT = int(os.getenv('MONGO_PORT', '30017'))
MONGO_USER = os.getenv('MONGO_USER', 'admin')
MONGO_PASS = os.getenv('MONGO_PASS', 'changeme')
MONGO_DB = os.getenv('MONGO_DB', 'myapp')

# Connection string
CONNECTION_STRING = f"mongodb://{MONGO_USER}:{MONGO_PASS}@{MONGO_HOST}:{MONGO_PORT}"

def connect_to_mongodb():
    """Conectar a MongoDB"""
    try:
        client = MongoClient(
            CONNECTION_STRING,
            serverSelectionTimeoutMS=5000
        )
        # Verificar conexión
        client.admin.command('ping')
        print(f"✓ Conectado a MongoDB en {MONGO_HOST}:{MONGO_PORT}")
        return client
    except ConnectionFailure as e:
        print(f"✗ Error de conexión: {e}")
        return None
    except Exception as e:
        print(f"✗ Error inesperado: {e}")
        return None

def create_sample_data(db):
    """Crear datos de ejemplo"""
    users_collection = db['users']

    # Crear índice único en email
    users_collection.create_index('email', unique=True)

    # Insertar usuarios de ejemplo
    sample_users = [
        {
            'name': 'Juan Pérez',
            'email': 'juan@example.com',
            'age': 30,
            'created_at': datetime.utcnow()
        },
        {
            'name': 'María García',
            'email': 'maria@example.com',
            'age': 25,
            'created_at': datetime.utcnow()
        },
        {
            'name': 'Carlos López',
            'email': 'carlos@example.com',
            'age': 35,
            'created_at': datetime.utcnow()
        }
    ]

    try:
        result = users_collection.insert_many(sample_users)
        print(f"\n✓ Insertados {len(result.inserted_ids)} usuarios")
        return True
    except Exception as e:
        print(f"\n✗ Error insertando usuarios: {e}")
        return False

def query_data(db):
    """Consultar datos"""
    users_collection = db['users']

    print("\n=== Todos los usuarios ===")
    for user in users_collection.find():
        print(f"- {user['name']} ({user['email']}) - {user['age']} años")

    print("\n=== Usuarios mayores de 30 ===")
    for user in users_collection.find({'age': {'$gt': 30}}):
        print(f"- {user['name']} - {user['age']} años")

    # Contar documentos
    total = users_collection.count_documents({})
    print(f"\n📊 Total de usuarios: {total}")

def update_data(db):
    """Actualizar datos"""
    users_collection = db['users']

    # Actualizar un usuario
    result = users_collection.update_one(
        {'email': 'juan@example.com'},
        {'$set': {'age': 31}}
    )

    if result.modified_count > 0:
        print("\n✓ Usuario actualizado")
    else:
        print("\n- No se actualizó ningún usuario")

def delete_data(db):
    """Eliminar datos"""
    users_collection = db['users']

    # Eliminar un usuario
    result = users_collection.delete_one({'email': 'carlos@example.com'})

    if result.deleted_count > 0:
        print("\n✓ Usuario eliminado")
    else:
        print("\n- No se eliminó ningún usuario")

def show_stats(db):
    """Mostrar estadísticas de la base de datos"""
    print("\n=== Estadísticas de la Base de Datos ===")

    # Listar colecciones
    collections = db.list_collection_names()
    print(f"\n📁 Colecciones: {', '.join(collections)}")

    # Estadísticas por colección
    for collection_name in collections:
        collection = db[collection_name]
        count = collection.count_documents({})
        print(f"  - {collection_name}: {count} documentos")

    # Estadísticas del servidor
    stats = db.command('dbStats')
    print(f"\n💾 Tamaño de la base de datos: {stats['dataSize'] / 1024 / 1024:.2f} MB")
    print(f"📊 Número de objetos: {stats['objects']}")

def main():
    """Función principal"""
    print("=" * 50)
    print("Cliente Python - MongoDB en K3s")
    print("=" * 50)

    # Conectar
    client = connect_to_mongodb()
    if not client:
        return

    # Seleccionar base de datos
    db = client[MONGO_DB]

    try:
        # Crear datos de ejemplo
        print("\n--- Creando datos de ejemplo ---")
        create_sample_data(db)

        # Consultar datos
        print("\n--- Consultando datos ---")
        query_data(db)

        # Actualizar datos
        print("\n--- Actualizando datos ---")
        update_data(db)
        query_data(db)

        # Eliminar datos
        print("\n--- Eliminando datos ---")
        delete_data(db)
        query_data(db)

        # Mostrar estadísticas
        show_stats(db)

    except Exception as e:
        print(f"\n✗ Error: {e}")

    finally:
        # Cerrar conexión
        client.close()
        print("\n✓ Conexión cerrada")

if __name__ == '__main__':
    main()
