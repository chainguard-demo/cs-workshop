ARG BUILDER_IMAGE="node:25"
ARG RUNTIME_IMAGE="node:25-slim"

FROM ${BUILDER_IMAGE}
WORKDIR /app
COPY package.json server.js ./
RUN npm install
ENV NODE_ENV=production
EXPOSE 3000
ENTRYPOINT ["node", "server.js"]
