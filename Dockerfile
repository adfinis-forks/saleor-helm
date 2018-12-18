### Forked from mirumee/saleor (BSD-3 License)
### https://github.com/mirumee/saleor/blob/e3057df41ab6c5689f381dff5f3d5721d685d183/Dockerfile#L2-L75


###########################
### Builder (python) image
###########################
FROM python:3.6 as build-python

RUN \
    apt-get -y update && \
    apt-get install -y gettext && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN pip install pipenv
ADD Pipfile /app/
ADD Pipfile.lock /app/
WORKDIR /app
RUN pipenv install --system --deploy --dev


###########################
### Builder (nodejs) image
###########################
FROM node:10 as build-nodejs

ARG STATIC_URL
ENV STATIC_URL ${STATIC_URL:-/static/}
ADD webpack.config.js app.json package.json package-lock.json tsconfig.json webpack.d.ts /app/
WORKDIR /app
RUN npm install

# Build static
ADD ./saleor/static /app/saleor/static/
ADD ./templates /app/templates/
RUN \
  STATIC_URL=${STATIC_URL} \
  npm run build-assets --production && \
  npm run build-emails --production


###########################
### Runtime (python) image
###########################
FROM python:3.6-slim

ARG STATIC_URL
ENV \
    STATIC_URL=${STATIC_URL:-/static/} \
    PYTHONUNBUFFERED=1
RUN \
    apt-get update && \
    apt-get install -y libxml2 libssl1.1 libcairo2 libpango-1.0-0 libpangocairo-1.0-0 libgdk-pixbuf2.0-0 shared-mime-info mime-support && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
ADD . /app
COPY --from=build-python /usr/local/lib/python3.6/site-packages/ /usr/local/lib/python3.6/site-packages/
COPY --from=build-python /usr/local/bin/ /usr/local/bin/
COPY --from=build-nodejs /app/saleor/static /app/saleor/static
COPY --from=build-nodejs /app/webpack-bundle.json /app/
COPY --from=build-nodejs /app/templates /app/templates
WORKDIR /app
USER 1001
RUN \
    python3 manage.py collectstatic --no-input && \
    useradd --non-unique --uid 1001 --gid 0 --create-home saleor && \
    mkdir -p /app/media /app/static && \
    chown -R 1001:0 /app
EXPOSE 8000

CMD ["uwsgi", "/app/saleor/wsgi/uwsgi.ini"]