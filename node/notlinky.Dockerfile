# Use the official Node.js image from the Docker Hub
FROM node:latest

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

# Command to run the Node.js application
CMD ["node", "index.js"]
