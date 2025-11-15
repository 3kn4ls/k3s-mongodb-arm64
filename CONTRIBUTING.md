# Guía de Contribución

¡Gracias por tu interés en contribuir a este proyecto!

## Cómo Contribuir

### Reportar Bugs

Si encuentras un bug, por favor crea un issue con:

1. **Descripción del problema**: Explica claramente el problema
2. **Pasos para reproducir**: Lista los pasos exactos para reproducir el bug
3. **Comportamiento esperado**: Qué esperabas que sucediera
4. **Comportamiento actual**: Qué sucedió realmente
5. **Entorno**:
   - Versión de Raspberry Pi OS
   - Versión de K3s
   - Versión de MongoDB
   - Cualquier otra información relevante
6. **Logs**: Incluye logs relevantes si es posible

### Sugerir Mejoras

Para sugerir una mejora:

1. Crea un issue describiendo la mejora
2. Explica por qué sería útil
3. Si es posible, proporciona ejemplos de uso

### Pull Requests

1. **Fork** el repositorio
2. **Crea una rama** desde `main`:
   ```bash
   git checkout -b feature/mi-nueva-caracteristica
   ```
3. **Haz tus cambios**:
   - Sigue el estilo de código existente
   - Añade comentarios cuando sea necesario
   - Actualiza la documentación si es relevante
4. **Prueba tus cambios**:
   - Verifica que todo funciona correctamente
   - Asegúrate de no romper funcionalidad existente
5. **Commit** tus cambios:
   ```bash
   git commit -m "Añadir: descripción clara de los cambios"
   ```
   Formato de mensajes de commit:
   - `Añadir: ...` para nuevas características
   - `Corregir: ...` para correcciones de bugs
   - `Actualizar: ...` para actualizaciones de código existente
   - `Documentar: ...` para cambios en documentación
6. **Push** a tu fork:
   ```bash
   git push origin feature/mi-nueva-caracteristica
   ```
7. **Crea un Pull Request** en GitHub

### Guía de Estilo

#### Scripts Bash

- Usar `#!/bin/bash` al inicio
- Incluir comentarios descriptivos
- Usar variables en MAYÚSCULAS para configuración
- Manejar errores apropiadamente con `set -e`
- Incluir mensajes de ayuda y uso

```bash
#!/bin/bash
# Descripción del script

set -e

# Configuración
VARIABLE_CONFIG="valor"

# Función principal
main() {
    echo "Haciendo algo..."
}

main "$@"
```

#### YAML de Kubernetes

- Indentar con 2 espacios
- Usar nombres descriptivos
- Incluir labels apropiadas
- Documentar con comentarios cuando sea necesario

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nombre-descriptivo
  namespace: mongodb
  labels:
    app: mongodb
spec:
  # Configuración...
```

#### Documentación

- Usar Markdown
- Incluir ejemplos de código
- Mantener estructura clara con headers
- Incluir tabla de contenidos para documentos largos
- Usar código formateado con ```bash o ```yaml

### Áreas de Contribución

Buscamos contribuciones en:

1. **Mejoras de scripts**:
   - Optimización de rendimiento
   - Mejor manejo de errores
   - Nuevas funcionalidades

2. **Documentación**:
   - Correcciones
   - Traducciones
   - Tutoriales adicionales
   - Casos de uso

3. **Ejemplos**:
   - Clientes en otros lenguajes (Go, Java, etc.)
   - Integraciones con frameworks
   - Casos de uso reales

4. **Características**:
   - Soporte para Replica Sets
   - Configuración de Sharding
   - Integración con monitoring (Prometheus/Grafana)
   - Helm Chart
   - CI/CD pipelines

5. **Testing**:
   - Tests automatizados
   - Scripts de validación
   - Benchmarks

### Proceso de Revisión

1. Un mantenedor revisará tu PR
2. Pueden solicitarse cambios
3. Una vez aprobado, se hará merge
4. Tu contribución aparecerá en el siguiente release

### Código de Conducta

- Sé respetuoso con otros contribuidores
- Acepta críticas constructivas
- Enfócate en lo mejor para el proyecto
- Ayuda a otros cuando sea posible

### Preguntas

Si tienes preguntas:
1. Revisa la [documentación](docs/)
2. Busca en issues existentes
3. Crea un nuevo issue con la etiqueta "pregunta"

## Licencia

Al contribuir, aceptas que tus contribuciones serán licenciadas bajo la licencia MIT del proyecto.

## Agradecimientos

¡Gracias por contribuir! Cada contribución, grande o pequeña, es valiosa.
