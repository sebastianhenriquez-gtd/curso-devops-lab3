# ---------- Etapa 1: build ----------
FROM node:22-alpine AS build

WORKDIR /app

# Instala dependencias (incluye devDependencies, necesarias para el build)
COPY package.json package-lock.json ./
RUN npm ci

# Copia el resto del código y compila
COPY . .
RUN npm run build

# Elimina devDependencies para dejar solo lo necesario en runtime
RUN npm prune --omit=dev

# ---------- Etapa 2: runtime ----------
FROM node:22-alpine AS runtime

ENV NODE_ENV=production
WORKDIR /app

# Usuario no root por seguridad
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copia solo lo necesario desde la etapa de build
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./package.json

USER appuser

EXPOSE 3000

CMD ["node", "dist/main"]
