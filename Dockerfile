FROM google/dart:1.24.0-dev.6.5

WORKDIR /app

ADD pubspec.* /app/
RUN pub get
ADD . /app
RUN pub get --offline

ENTRYPOINT ["/usr/bin/dart", "bin/main.dart"]
