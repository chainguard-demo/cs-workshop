ARG ORG=cs-ttt-demo.dev

FROM cgr.dev/${ORG}/node:20

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

RUN npm run build && npm prune --omit=dev

ENV LOG_DIR=/app/logs

EXPOSE 80
ENTRYPOINT ["node"]
CMD ["server.js"]
