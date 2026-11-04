FROM node:24-alpine AS web
WORKDIR /web
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
RUN npm test && npm run build

FROM caddy:2-alpine
COPY server/Caddyfile /etc/caddy/Caddyfile
COPY --from=web /web/dist /srv
EXPOSE 8080
