FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY *.js ./
CMD ["node", "server.js"]
