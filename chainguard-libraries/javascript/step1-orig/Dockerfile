FROM node:25
WORKDIR /app
COPY package.json server.js ./
RUN npm install
ENV NODE_ENV=production
EXPOSE 3000
ENTRYPOINT ["node", "server.js"]
