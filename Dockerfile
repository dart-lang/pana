FROM google/dart:1.13.0-dev.3.1

WORKDIR /app

ADD pubspec.* /app/
RUN pub get
ADD . /app
RUN pub get --offline

ENTRYPOINT ["dart", "bin/panastrong.dart"]
