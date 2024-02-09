FROM python:3-alpine
ENV SQLALCHEMY_DATABASE_URI="postgresql://twoge:twoge@postgres_twoge:5432/twoge"
RUN apk update && \
    apk add --no-cache build-base libffi-dev openssl-dev
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
EXPOSE 80
CMD ["gunicorn"  , "--bind", "0.0.0.0:80", "app:app"]



