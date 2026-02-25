- [Chainguard Libraries Workshops](#chainguard-libraries-workshops)
  - [🟨 Java Workshop](#-java-workshop)
  - [🐍 Python Workshop](#-python-workshop)
  - [🟦 JavaScript Workshop](#-javascript-workshop)
  - [🛡️ Python CVE Mitigation Workshop *(Coming Soon)*](#️-python-cve-mitigation-workshop-coming-soon)
  - [📘 About These Workshops](#-about-these-workshops)
  - [🚀 Getting Started](#-getting-started)


# Chainguard Libraries Workshops

This repository contains hands-on workshops demonstrating how to migrate existing applications to **Chainguard Libraries** using secure, reproducible supply chain practices. Each workshop walks through baseline builds, migration steps, full Chainguard builds, provenance inspection, scanning, and cleanup.

Choose the workshop that matches the language ecosystem or topic you want to explore:

---

## 🟨 Java Workshop  
**Folder:** [`java/`](java/)

The Java workshop guides you through rebuilding a Spring Boot application using:
- Upstream Maven Central 
- Chainguard Libraries with upstream Maven and Temurin images
- Chainguard Libraries with Maven + JRE Chainguard build images  
- Dependency provenance and SBOM inspection  
- chainctl scanning and verification of dependency origin

This is ideal for teams using Maven- or Gradle-based Java applications who want to learn how to replace upstream dependencies with Chainguard-verified artifacts.

Start here → [`java/`](java/readme.md)

---

## 🐍 Python Workshop  
**Folder:** [`python/`](python/)

The Python workshop walks you through rebuilding a Flask application using:
- Upstream Python + PyPI  
- Chainguard Libraries via `uv` with upstream Python images  
- Full Chainguard Python build/runtime images  
- Dependency provenance and SBOM inspection  
- chainctl scanning and verification of dependency origin

This workshop is ideal for teams using Python and wanting to migrate from PyPI to Chainguard’s verified Python ecosystem.

Start here → [`python/`](python/readme.md)

---

## 🟦 JavaScript Workshop
**Folder:** [`javascript/`](javascript/)

The JavaScript workshop walks you through rebuilding an Express.js application using:
- Upstream npm registry with Node.js images
- Chainguard Libraries with multiple package managers:
  - **npm** - Node Package Manager (default)
  - **pnpm** - Fast, disk space efficient package manager
  - **Yarn** - Modern package manager with workspaces support
  - **Bun** - Fast all-in-one JavaScript runtime and toolkit
- chainctl scanning and verification of dependency origin

This workshop is ideal for teams using Node.js applications and wanting to migrate from the public npm registry to Chainguard's verified JavaScript ecosystem, regardless of which package manager they prefer.

Start here → [`javascript/`](javascript/readme.md)

---

## 🛡️ Python CVE Mitigation Workshop *(Coming Soon)*  
**Folder:** `python-cve-mitigation/` *(placeholder)*

🧯 **Status:** *Content coming soon — workshop under development!*

---

## 📘 About These Workshops

All workshops demonstrate:

1. How to pull dependencies from **Chainguard Libraries** instead of upstream sources.  
2. How to scan applications with **chainctl** to confirm dependency origin.  
3. How to view **provenance** for Chainguard Libraries

---

## 🚀 Getting Started

Clone this repository and navigate to your desired workshop:

```bash
git clone https://github.com/chainguard-demo/cs-workshop
cd chainguard-libraries/java
# -- or --
cd chainguard-libraries/python
# -- or --
cd chainguard-libraries/javascript
```

Follow the detailed walkthrough inside each folder (or placeholder) to complete the workshop or run the demo.sh script for a scripted walkthrough.
