# Python Example: Base Chroot

This is an example of migrating a Python application to Chainguard. It
demonstrates using the 'base chroot' method to install packages into distroless
images.

## Steps

### Using Upstream Image

1. Build the image.

```
docker build -t python-example:0 -f 0.Dockerfile .
```

2. Run the image.

```
docker run --rm python-example:0
```

3. Check the size.

```
docker images python-example:0
```

4. Scan it for vulnerabilities.

```
grype python-example:0
```

### Using Chainguard Images (Example 1)

1. View the differences with the original Dockerfile.

```
git diff --no-index -U1000 0.Dockerfile 2.Dockerfile
```

2. Build the image.

```
docker build -t python-example:1 -f 1.Dockerfile .
```

This will fail when we try to run it because the MariaDB packages that are
included by default in the upstream image are not available out of the box in the
Chainguard image.

We need to install MariaDB as part of the '-dev' stage. See Example 2.

### Using Chainguard Images (Example 2)

1. View the differences between this example and the previous one.

```
git diff --no-index -U1000 1.Dockerfile 2.Dockerfile
```

2. Build the image.

```
docker build -t python-example:2 -f 2.Dockerfile .
```

This will fail when we try to run it because the MariaDB packages that are
installed in the dev stage are not available in the final stage. 

We need to install the packages into the final stage. See Example 3.

```
  File "/app/run.py", line 1, in <module>
    from MySQLdb import _mysql
  File "/app/venv/lib/python3.12/site-packages/MySQLdb/__init__.py", line 17, in <module>
    from . import _mysql
ImportError: libmariadb.so.3: cannot open shared object file: No such file or
directory
```

### Using Chainguard Images (Example 3)

1. View the differences between this example and the previous one.

```
git diff --no-index -U1000 2.Dockerfile 3.Dockerfile
```

2. Build the image.

```
docker build -t python-example:3 -f 3.Dockerfile .
```

3. Run the image.

```
docker run --rm python-example:3
```

4. Check the size compared to the original image.

```
docker images python-example:0
docker images python-example:3
```

5. Scan it for vulnerabilities.

```
grype python-example:3
```
