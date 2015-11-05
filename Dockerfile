FROM kevmoo/dart:1.13.0-dev.7.6

WORKDIR /app

ADD pubspec.yaml pubspec.lock /app/
RUN pub get
ADD . /app
RUN pub get --offline

ENTRYPOINT ["dart", "bin/pana.dart"]
