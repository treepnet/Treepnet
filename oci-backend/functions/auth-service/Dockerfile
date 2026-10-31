FROM node:24-alpine
WORKDIR /app
# Exact versions from the lockfile.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY server.js ./
# Not root. uid 1001 is the server account that owns the mounted secrets
# (mode 600), so they stay readable without opening them up.
RUN addgroup -g 1001 app && adduser -u 1001 -G app -D -H app
USER app
CMD ["node", "server.js"]
