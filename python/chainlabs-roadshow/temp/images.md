If you encounter rate limiting issues while trying to pull public images, follow these steps to download the images from object storage instead.

# 1) Download the artifact

### amd64

```sh
curl -O "https://temp-chainlabs-roadshows.s3.us-east-1.amazonaws.com/images-amd64.zip?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ASIAWSUKZ3EFQSBFL4PZ%2F20251005%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20251005T234639Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEOj%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJHMEUCIQD%2FlBD%2F5f8Fup%2FuWJYsNz0ZxngNV3zKM%2Fnsva4XlYIS4QIgdaU4UvIMLa8HTyGgL8K%2FDxYrvEddLjBdWy8UZ5I%2BYbEqnAMIgf%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARACGgw0NTIzMzY0MDg4NDMiDJH%2FQCy89q%2FyJUCxDCrwAjicRp2d1xbHa5K1xgXj1%2BnbNXVCjsAvbUkHwjGhMKrera9TY58NM6JrRn5A2ogBLV0LgZvCgAta1k6VBHrHqwisXZep%2FewMJSfLuGIcGGfDRZwkJ7wiTTnD6ImMjEyJoalxk1mw4jrBamgXRmDDUzMoOAMlXmJfqvqRHVBjvOfKo56IhUfJnz1LiLGFYYyQ6FWNF0%2Bm948uVDSpG4T8q74NoyjNgMmY3mSvHsnprO%2B7%2FSpReAmNcOWziBByTRPfFQfZ%2BWVtjxT3w2wJCfzWugdlNbTPhwBzh%2Fq%2F92yCHgtESv03WUPav0jm7wzlJLWhTQi84Rrq6JEMciox6d2X15akEzN1wRQWKeiBMr9rZGZVNJWbBE%2BdB4acu8d9qpw7dI6tqNKGvsG2dRpZZUxbQvbrDKtZ6cWnSUtc6XpII00Wo9osXTVdGoz8WlFG%2Fefta%2BaUWky%2Bmr1qENM3hSK7JmHOryUXKOvEcsaLv8aAte2uMPD7i8cGOqYBnCqb%2FtVMO%2BMHc5OeThSY7027KlBzg83zaRjp4vytLBgE96O80YAn6GKd87jM3VD40MwEW5yz7uQsAfXFZYnEpUwLcRLoV8%2FxM4%2BGBgxBhPvDZvD37UVMSlUTUuv1NqtWMzKAO%2Fcl4Q4il0gMSHU4aHl3davClKegDp3aj54lOzi1SgrZ2wcAhDWJ7l6W1JYij0hf%2BxKH%2FfNWgMKKKnZG4PhzL6mZVA%3D%3D&X-Amz-Signature=5ef850592f706be5f4ac5b101f34e633162d6e6069233dd0c5bffaafcd027abd"
```

### arm64

```sh
curl -O "https://temp-chainlabs-roadshows.s3.us-east-1.amazonaws.com/images-arm64.zip?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ASIAWSUKZ3EFQSBFL4PZ%2F20251005%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20251005T234913Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEOj%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJHMEUCIQD%2FlBD%2F5f8Fup%2FuWJYsNz0ZxngNV3zKM%2Fnsva4XlYIS4QIgdaU4UvIMLa8HTyGgL8K%2FDxYrvEddLjBdWy8UZ5I%2BYbEqnAMIgf%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARACGgw0NTIzMzY0MDg4NDMiDJH%2FQCy89q%2FyJUCxDCrwAjicRp2d1xbHa5K1xgXj1%2BnbNXVCjsAvbUkHwjGhMKrera9TY58NM6JrRn5A2ogBLV0LgZvCgAta1k6VBHrHqwisXZep%2FewMJSfLuGIcGGfDRZwkJ7wiTTnD6ImMjEyJoalxk1mw4jrBamgXRmDDUzMoOAMlXmJfqvqRHVBjvOfKo56IhUfJnz1LiLGFYYyQ6FWNF0%2Bm948uVDSpG4T8q74NoyjNgMmY3mSvHsnprO%2B7%2FSpReAmNcOWziBByTRPfFQfZ%2BWVtjxT3w2wJCfzWugdlNbTPhwBzh%2Fq%2F92yCHgtESv03WUPav0jm7wzlJLWhTQi84Rrq6JEMciox6d2X15akEzN1wRQWKeiBMr9rZGZVNJWbBE%2BdB4acu8d9qpw7dI6tqNKGvsG2dRpZZUxbQvbrDKtZ6cWnSUtc6XpII00Wo9osXTVdGoz8WlFG%2Fefta%2BaUWky%2Bmr1qENM3hSK7JmHOryUXKOvEcsaLv8aAte2uMPD7i8cGOqYBnCqb%2FtVMO%2BMHc5OeThSY7027KlBzg83zaRjp4vytLBgE96O80YAn6GKd87jM3VD40MwEW5yz7uQsAfXFZYnEpUwLcRLoV8%2FxM4%2BGBgxBhPvDZvD37UVMSlUTUuv1NqtWMzKAO%2Fcl4Q4il0gMSHU4aHl3davClKegDp3aj54lOzi1SgrZ2wcAhDWJ7l6W1JYij0hf%2BxKH%2FfNWgMKKKnZG4PhzL6mZVA%3D%3D&X-Amz-Signature=1efda279081a6ac63a3d6725dcd1abbd957ce77d8411f62bf0e29c9e4aaae37e"
```

# 2) Set architecture variable (amd64 or arm64)

```sh
ARCH="<YOUR_ARCHITECTURE>"
```

# 3) Unzip the artifact

```sh
unzip images-$ARCH.zip
```

# 4) Load docker images locally

```sh
docker load -i ./images-$ARCH/chps-scorer-$ARCH.tar
docker load -i ./images-$ARCH/deb-python312-$ARCH.tar
docker load -i ./images-$ARCH/grype-$ARCH.tar
docker load -i ./images-$ARCH/ubi-python312-$ARCH.tar
```