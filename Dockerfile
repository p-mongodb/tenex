FROM debian:testing

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
  apt-get -y install git ruby-dev libxml2-dev libxslt-dev \
    gcc zlib1g-dev patch pkg-config make curl libcurl4-gnutls-dev gnupg

#RUN curl -sfL https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add - && \
#  echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list && \
#  apt-get update && \
#  apt-get -y install mongodb-org-server

RUN gem install bundler --no-document && \
  gem install nokogiri --no-document -- --use-system-libraries

WORKDIR /app
COPY Gemfile .
COPY Gemfile.lock .
RUN bundle install
COPY . .
RUN rm -rf /app/config && ln -s /etc/tenex /app/config

CMD ["bundle", "exec", "puma", ".config.ru", "-b", "tcp://0.0.0.0:80", "-e", "production"]
ENTRYPOINT ["/app/entrypoint.sh"]
EXPOSE 80
