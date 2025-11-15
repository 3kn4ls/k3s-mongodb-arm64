# Ejemplo de Cliente Python para MongoDB

Este ejemplo muestra cómo conectarse a MongoDB en K3s usando Python.

## Requisitos

- Python 3.7 o superior
- pip

## Instalación

```bash
# Crear entorno virtual (recomendado)
python3 -m venv venv
source venv/bin/activate  # En Windows: venv\Scripts\activate

# Instalar dependencias
pip install -r requirements.txt
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

O editar directamente en `app.py`.

## Uso

```bash
python app.py
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

## Ejemplo de Salida

```
==================================================
Cliente Python - MongoDB en K3s
==================================================
✓ Conectado a MongoDB en 192.168.1.100:30017

--- Creando datos de ejemplo ---
✓ Insertados 3 usuarios

--- Consultando datos ---

=== Todos los usuarios ===
- Juan Pérez (juan@example.com) - 30 años
- María García (maria@example.com) - 25 años
- Carlos López (carlos@example.com) - 35 años

📊 Total de usuarios: 3

=== Estadísticas de la Base de Datos ===
📁 Colecciones: users
  - users: 3 documentos

💾 Tamaño de la base de datos: 0.04 MB
```

## Uso en tu Aplicación

```python
from pymongo import MongoClient

# Conectar
client = MongoClient("mongodb://admin:password@192.168.1.100:30017")
db = client['myapp']

# Insertar
db.users.insert_one({'name': 'Test', 'email': 'test@example.com'})

# Consultar
user = db.users.find_one({'email': 'test@example.com'})

# Actualizar
db.users.update_one(
    {'email': 'test@example.com'},
    {'$set': {'name': 'Updated Name'}}
)

# Eliminar
db.users.delete_one({'email': 'test@example.com'})
```

## Conexión desde Kubernetes

Si tu aplicación Python corre dentro del cluster K3s:

```python
CONNECTION_STRING = "mongodb://admin:password@mongodb-service.mongodb.svc.cluster.local:27017"
```

## Recursos

- [PyMongo Documentation](https://pymongo.readthedocs.io/)
- [MongoDB Python Tutorial](https://www.mongodb.com/languages/python)
