# jlink — Minimal JRE Demo

Demonstrates using `jlink` (JDK 25) to assemble a custom minimal JRE containing only the modules your application actually needs, then shipping it on Chainguard's `glibc-dynamic` base.

## How it works

| Stage | Image | What happens |
|-------|-------|-------------|
| `builder` | `cgr.dev/chainguard-private/jdk:openjdk-25-dev` | Compiles the app, packages it as a JAR, runs `jdeps` to find required modules, then calls `jlink` to produce `/custom-jre` |
| runtime | `cgr.dev/chainguard-private/glibc-dynamic` | Copies in only the custom JRE and the JAR — no full JDK, no package manager |

`jdeps --print-module-deps` scans the JAR and outputs a comma-separated list of required modules (e.g. `java.base,java.logging`). That list feeds directly into `jlink --add-modules`, so the custom JRE is no larger than it needs to be.

## Build & run

```sh
docker build -t jlink-demo .
docker run --rm jlink-demo
```

Expected output:
```
Hello from a custom JRE built with jlink!
Java version: 25
Java runtime: OpenJDK Runtime Environment
```

## Why this matters

- A full JDK image is hundreds of MB and carries every module and tool.
- A `jlink`-assembled JRE includes only the modules in use, dramatically reducing attack surface and image size.
- The `glibc-dynamic` runtime base is a minimal, hardened Chainguard image — no shell, no package manager, distroless by default.
