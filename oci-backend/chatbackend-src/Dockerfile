FROM node:24-slim
WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Exact versions from the lockfile.
COPY package.json package-lock.json ./
COPY prisma ./prisma
RUN npm ci --omit=dev && npx prisma generate && npm cache clean --force

COPY . .

# Not root. uid 1001 is the server account that owns the mounted secrets
# (mode 600), so they stay readable without opening them up.
RUN groupadd -g 1001 app && useradd -u 1001 -g app -m app
USER app

EXPOSE 3000

CMD ["sh", "-c", "npx prisma db push --skip-generate && node index.js"]
