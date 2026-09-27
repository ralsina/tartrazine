# syntax=docker/dockerfile:1
FROM alpine:3.20 AS build
ARG VERSION=1.0
ENV APP_HOME=/app \
    LANG=C.UTF-8
WORKDIR $APP_HOME
RUN apk add --no-cache build-base && \
    echo "building ${VERSION}"
COPY . .
RUN make release

FROM alpine:3.20
COPY --from=build /app/bin/app /usr/local/bin/app
EXPOSE 8080/tcp
USER nobody
HEALTHCHECK --interval=30s CMD ["/usr/local/bin/app", "--health"]
ENTRYPOINT ["/usr/local/bin/app"]
CMD ["--port", "8080"]
