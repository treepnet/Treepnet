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

# node itself is PID 1, so a stop's SIGTERM reaches it (index.js closes the
# sockets and the database); under `sh -c` it never did, and every deploy
# waited 10 s and killed it. The schema is no longer pushed at boot: a change
# that `db push` refuses (a new unique index) kept chat from starting. Schema
# changes are applied by hand first: prisma/manual/README.md.
CMD ["node", "index.js"]
