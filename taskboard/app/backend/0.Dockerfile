FROM node:20-alpine
WORKDIR /app

COPY . .
RUN npm install && npm prune --omit=dev

EXPOSE 8080
ENTRYPOINT ["node"]
CMD ["server.js"]
