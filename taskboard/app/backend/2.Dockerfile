ARG ORG=cs-ttt-demo.dev

FROM cgr.dev/${ORG}/node:20-dev AS build
WORKDIR /app

COPY . .
RUN npm install && npm prune --omit=dev

FROM cgr.dev/${ORG}/node:20-slim
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/server.js ./server.js

EXPOSE 8080
ENTRYPOINT ["/usr/bin/dumb-init", "--", "node"]
CMD ["server.js"]
