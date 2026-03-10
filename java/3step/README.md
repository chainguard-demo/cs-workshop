## Java Example 1

A simple Java HTTP server built and run in a single stage using the `eclipse-temurin:21-jdk` image.

```
docker build -t java-example:1 ./step1-orig
```

Run
```
docker run -d -p 8081:8080 java-example:1
```

## Java Example 2

Multi-stage build: `eclipse-temurin:21-jdk` compiles the app, `eclipse-temurin:21-jre` runs it.

```
docker build -t java-example:2 ./step2-orig-multi
```

Run
```
docker run -d -p 8082:8080 java-example:2
```

## Java Example 3

Multi-stage build using Chainguard `jdk` and `jre` images — minimal, hardened base images with fewer CVEs.

```
docker build -t java-example:3 ./step3-cg-multi
```

Run
```
docker run -d -p 8083:8080 java-example:3
```
