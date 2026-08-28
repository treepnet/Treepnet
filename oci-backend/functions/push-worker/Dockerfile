FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY push-worker.js ./
CMD ["node", "push-worker.js"]
