# syntax=docker/dockerfile:1

FROM node:16

ENV NODE_ENV=production

# use following path as default location for subsequent commands
WORKDIR /app

# only copy package.json to take advantage of cached Doker layers
COPY ["package.json", "package-lock.json", "./"]

RUN npm ci --production

COPY . .

CMD ["node", "index.js"]