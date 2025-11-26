# Use the Node.js image from Chainguard
FROM cgr.dev/chainguard/node:latest-dev AS builder

# Set the working directory inside the container
WORKDIR /usr/src/app

# Copy package.json and package-lock.json (if available)
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the image into the container
ARG IMAGE
COPY ${IMAGE} ./image.jpg

# Copy the rest of the application code
COPY . .

# Use the -slim variant as the final stage
FROM cgr.dev/chainguard/node:latest-slim

# Copy in the application, ensure it is owned by the 'node' user
COPY --from=builder --chown=node:node /usr/src/app /app

# Ensure node_modules are in the PATH
ENV PATH=/app/node_modules/.bin:$PATH

# Set the working directory to the application
WORKDIR /app

# Use dumb-init as PID 1 so it can handle signals etc
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Command to run the Node.js application
CMD ["node", "index.js"]
