# Secrets de MongoDB

## Creación de Secrets

Este directorio contiene plantillas para los secrets de MongoDB.

### Opción 1: Usar el archivo de ejemplo

1. Copiar el archivo de ejemplo:
```bash
cp secret.yaml.example secret.yaml
```

2. Editar `secret.yaml` y cambiar las credenciales:
```bash
# Usar un editor de texto
nano secret.yaml
# o
vim secret.yaml
```

3. Aplicar el secret:
```bash
kubectl apply -f secret.yaml
```

### Opción 2: Crear secret desde línea de comandos

```bash
kubectl create secret generic mongodb-secret \
  --from-literal=username=admin \
  --from-literal=password=tu-contraseña-segura \
  --from-literal=connection-string=mongodb://admin:tu-contraseña-segura@mongodb-service.mongodb.svc.cluster.local:27017 \
  --namespace=mongodb
```

### Opción 3: Usar el script de generación

```bash
cd ../../scripts
./generate-secrets.sh
```

## Seguridad

**IMPORTANTE:**
- Nunca hacer commit de `secret.yaml` en el repositorio
- El archivo `secret.yaml` está en `.gitignore`
- Usar contraseñas fuertes en producción
- Rotar las contraseñas periódicamente

## Verificar el secret

```bash
kubectl get secret mongodb-secret -n mongodb
kubectl describe secret mongodb-secret -n mongodb
```

## Ver el contenido del secret (decodificado)

```bash
kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.username}' | base64 -d
kubectl get secret mongodb-secret -n mongodb -o jsonpath='{.data.password}' | base64 -d
```
