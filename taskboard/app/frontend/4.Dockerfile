ARG ORG=cs-ttt-demo.dev

FROM cgr.dev/${ORG}/node:20-dev AS build

USER root
RUN apk add --no-cache posix-libc-utils-bin
USER 65532

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

RUN npm run build && npm prune --omit=dev

FROM cgr.dev/${ORG}/node:20

COPY --from=build /usr/bin/getconf /usr/bin/getconf

WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/server.js ./server.js

ENV LOG_DIR=/app/logs

EXPOSE 80
ENTRYPOINT ["node"]
CMD ["server.js"]
