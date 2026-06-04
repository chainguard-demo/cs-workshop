FROM node:20

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

RUN npm run build && npm prune --omit=dev

EXPOSE 80
ENTRYPOINT ["node"]
CMD ["server.js"]
