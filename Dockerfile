FROM debian:10

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install ruby-dev libxml2-dev libxslt-dev \
  gcc zlib1g-dev patch pkg-config make

RUN gem install bundler --no-document
RUN gem install nokogiri --no-document -- --use-system-libraries

WORKDIR /app
COPY Gemfile .
COPY Gemfile.lock .
RUN bundle install
COPY . .

CMD ["puma", ".config.ru", "-b", "tcp://0.0.0.0:80", "-e", "production"]
ENTRYPOINT ["/app/entrypoint.sh"]
EXPOSE 80
