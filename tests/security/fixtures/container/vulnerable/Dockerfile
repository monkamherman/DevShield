FROM node:22.14.0-alpine3.21
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts
CMD ["node", "-e", "" ]
