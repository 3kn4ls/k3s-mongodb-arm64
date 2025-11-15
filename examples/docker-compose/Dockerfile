FROM node:18-alpine

WORKDIR /app

# Copiar package.json y package-lock.json
COPY package*.json ./

# Instalar dependencias
RUN npm ci --only=production

# Copiar código de la aplicación
COPY . .

# Exponer puerto (si tu app es un servidor web)
EXPOSE 3000

# Comando para ejecutar la aplicación
CMD ["node", "app.js"]
