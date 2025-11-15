# MongoDB en K3s para Raspberry Pi 5 (ARM64)

Despliegue completo de MongoDB en un cluster K3s optimizado para Raspberry Pi 5 con arquitectura ARM64.

## 📋 Características

- ✅ Despliegue de MongoDB 7.0 compatible con ARM64
- ✅ Persistencia de datos con StorageClass local-path
- ✅ StatefulSet para alta disponibilidad
- ✅ Services internos y externos (NodePort)
- ✅ Configuración optimizada para Raspberry Pi 5
- ✅ Scripts de backup y restauración automáticos
- ✅ Monitoreo y mantenimiento
- ✅ Seguridad con Secrets de Kubernetes

## 🚀 Inicio Rápido

### Prerrequisitos

- Raspberry Pi 5 con Raspberry Pi OS (64-bit)
- Al menos 4GB de RAM (8GB recomendado)
- 20GB de espacio libre en disco
- Conexión a Internet

### Instalación en 3 pasos

1. **Instalar K3s:**
```bash
cd scripts
./install-k3s.sh
```

2. **Generar credenciales de MongoDB:**
```bash
./generate-secrets.sh
```

3. **Desplegar MongoDB:**
```bash
./deploy-mongodb.sh
```

## 📁 Estructura del Proyecto

```
k3s-mongodb-arm64/
├── k8s/                          # Manifiestos de Kubernetes
│   ├── mongodb/                  # Recursos de MongoDB
│   │   ├── namespace.yaml        # Namespace mongodb
│   │   ├── configmap.yaml        # Configuración de MongoDB
│   │   ├── service.yaml          # Services (interno y externo)
│   │   └── statefulset.yaml      # StatefulSet de MongoDB
│   ├── storage/                  # Recursos de almacenamiento
│   │   └── storageclass.yaml     # StorageClass para PVCs
│   └── secrets/                  # Secrets (no versionados)
│       ├── secret.yaml.example   # Plantilla de secret
│       └── README.md             # Guía de secrets
├── scripts/                      # Scripts de automatización
│   ├── install-k3s.sh           # Instalación de K3s
│   ├── generate-secrets.sh       # Generador de secrets
│   ├── deploy-mongodb.sh         # Despliegue de MongoDB
│   ├── uninstall-mongodb.sh      # Desinstalación
│   ├── backup-mongodb.sh         # Backup manual
│   ├── restore-mongodb.sh        # Restauración
│   ├── monitor-mongodb.sh        # Monitoreo
│   └── setup-cronjob-backup.sh   # Configurar backups automáticos
├── docs/                         # Documentación detallada
│   ├── INSTALLATION.md           # Guía de instalación
│   ├── CONFIGURATION.md          # Configuración avanzada
│   ├── TROUBLESHOOTING.md        # Solución de problemas
│   └── BACKUP.md                 # Guía de backups
├── examples/                     # Ejemplos de uso
│   ├── python-client/            # Cliente Python
│   ├── nodejs-client/            # Cliente Node.js
│   └── docker-compose/           # Ejemplo con Docker Compose
└── README.md                     # Este archivo
```

## 🔧 Configuración

### Parámetros de MongoDB

El StatefulSet está configurado con:
- **Imagen:** mongo:7.0 (compatible ARM64)
- **Recursos:**
  - Requests: 512Mi RAM, 500m CPU
  - Limits: 2Gi RAM, 2000m CPU
- **Almacenamiento:** 10Gi (ajustable)
- **Puerto interno:** 27017
- **Puerto externo:** 30017 (NodePort)

### Variables de Entorno

Las credenciales se gestionan mediante Secrets de Kubernetes:
- `MONGO_INITDB_ROOT_USERNAME`: Usuario administrador
- `MONGO_INITDB_ROOT_PASSWORD`: Contraseña del administrador

## 📊 Monitoreo

Monitorear el estado de MongoDB:

```bash
# Monitoreo completo
./scripts/monitor-mongodb.sh

# Monitoreo continuo (auto-refresh cada 5s)
./scripts/monitor-mongodb.sh --watch

# Ver logs en tiempo real
kubectl logs -f mongodb-0 -n mongodb

# Estado de recursos
kubectl get all -n mongodb
```

## 💾 Backups

### Backup Manual

```bash
./scripts/backup-mongodb.sh
```

Los backups se guardan en `~/mongodb-backups/` por defecto.

### Backup Automático

Configurar backups diarios a las 2:00 AM:

```bash
./scripts/setup-cronjob-backup.sh
```

### Restauración

```bash
./scripts/restore-mongodb.sh mongodb_backup_20240115_020000.tar.gz
```

## 🔌 Conexión a MongoDB

### Desde dentro del cluster

```bash
mongodb://admin:PASSWORD@mongodb-service.mongodb.svc.cluster.local:27017
```

### Desde fuera del cluster

```bash
mongodb://admin:PASSWORD@<RASPBERRY_PI_IP>:30017
```

### Usando mongosh

```bash
# Desde el pod
kubectl exec -it mongodb-0 -n mongodb -- mongosh -u admin -p

# Desde tu máquina local (instalar mongosh primero)
mongosh "mongodb://admin:PASSWORD@<RASPBERRY_PI_IP>:30017"
```

### Obtener credenciales

```bash
# Usuario
kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.username}' | base64 -d

# Password
kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.password}' | base64 -d
```

## 🛠️ Comandos Útiles

```bash
# Ver todos los recursos de MongoDB
kubectl get all -n mongodb

# Describir el pod
kubectl describe pod mongodb-0 -n mongodb

# Ver logs
kubectl logs mongodb-0 -n mongodb

# Ejecutar comando en el pod
kubectl exec -it mongodb-0 -n mongodb -- bash

# Ver uso de recursos
kubectl top pod mongodb-0 -n mongodb

# Escalar (si es necesario)
kubectl scale statefulset mongodb -n mongodb --replicas=1

# Ver eventos
kubectl get events -n mongodb --sort-by='.lastTimestamp'
```

## 🔒 Seguridad

### Mejores Prácticas

1. **Cambiar credenciales por defecto:** Siempre usar contraseñas fuertes
2. **Limitar acceso externo:** Usar NetworkPolicies si es necesario
3. **Actualizar regularmente:** Mantener MongoDB actualizado
4. **Backups regulares:** Configurar backups automáticos
5. **Monitoreo:** Revisar logs y métricas regularmente

### Rotar Contraseñas

```bash
# 1. Generar nuevo secret
./scripts/generate-secrets.sh

# 2. Aplicar nuevo secret
kubectl apply -f k8s/secrets/secret.yaml

# 3. Reiniciar MongoDB
kubectl rollout restart statefulset mongodb -n mongodb
```

## 📚 Documentación Adicional

- [Guía de Instalación Detallada](docs/INSTALLATION.md)
- [Configuración Avanzada](docs/CONFIGURATION.md)
- [Solución de Problemas](docs/TROUBLESHOOTING.md)
- [Guía de Backups](docs/BACKUP.md)

## 🐛 Solución de Problemas

### MongoDB no inicia

```bash
# Ver logs
kubectl logs mongodb-0 -n mongodb

# Ver eventos
kubectl describe pod mongodb-0 -n mongodb

# Verificar recursos
kubectl get pvc -n mongodb
```

### Problemas de conexión

```bash
# Verificar services
kubectl get svc -n mongodb

# Probar conexión desde el pod
kubectl exec -it mongodb-0 -n mongodb -- mongosh --eval "db.adminCommand('ping')"
```

### Espacio en disco

```bash
# Ver uso de disco en el nodo
df -h

# Ver tamaño de datos de MongoDB
kubectl exec mongodb-0 -n mongodb -- du -sh /data/db
```

## 🗑️ Desinstalación

Para desinstalar MongoDB completamente:

```bash
./scripts/uninstall-mongodb.sh
```

**Nota:** Esto eliminará todos los datos. Asegúrate de hacer un backup primero.

## 📄 Licencia

Este proyecto está bajo licencia MIT. Ver archivo LICENSE para más detalles.

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📞 Soporte

Si tienes problemas o preguntas:

1. Revisa la [documentación](docs/)
2. Busca en los [issues existentes](issues)
3. Crea un nuevo issue con detalles del problema

## ✨ Características Futuras

- [ ] Soporte para Replica Set
- [ ] Configuración de sharding
- [ ] Integración con Prometheus/Grafana
- [ ] Helm Chart
- [ ] Soporte para backup en S3/MinIO
- [ ] NetworkPolicies para seguridad
- [ ] Certificados TLS/SSL

## 🙏 Agradecimientos

- [K3s](https://k3s.io/) - Lightweight Kubernetes
- [MongoDB](https://www.mongodb.com/) - Base de datos NoSQL
- [Raspberry Pi](https://www.raspberrypi.org/) - Hardware ARM
