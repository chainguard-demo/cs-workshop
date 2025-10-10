FROM cgr.dev/chainguard/wolfi-base

RUN apk --no-cache add wget

WORKDIR /workdir

RUN wget -O nginx.tar.gz https://github.com/nginx/nginx/releases/download/release-1.27.2/nginx-1.27.2.tar.gz
RUN tar -xzvf nginx.tar.gz
RUN rm nginx.tar.gz
