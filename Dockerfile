FROM google/dart:1.23.0-dev.11.5

WORKDIR /app

ADD pubspec.* /app/
RUN pub get
ADD . /app
RUN pub get --offline

ENTRYPOINT ["/usr/bin/dart", "bin/main.dart"]
