# Version tag is explicit but not immutable; Phase 07 will enforce digests.
FROM node:22.23.2-alpine3.24
WORKDIR /app
ENV NODE_ENV=production PORT=3000
COPY --chown=node:node apps/fixture/package.json apps/fixture/package-lock.json ./
RUN apk upgrade --no-cache \
      && npm ci --omit=dev --ignore-scripts \
      && npm cache clean --force \
      && rm -rf /usr/local/lib/node_modules/npm \
                /usr/local/bin/npm \
                /usr/local/bin/npx
COPY --chown=node:node apps/fixture/server.js ./server.js
USER node
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD node -e "require('node:http').get('http://127.0.0.1:3000/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"
CMD ["node", "server.js"]
