FROM google/dart:1.25.0-dev.3.0

# Required for flutter install
RUN apt-get update && \
  apt-get install -y unzip

# Used to ensure actions from this container are not seen as "typical" users
ENV PUB_ENVIRONMENT="bot.pkg_pana.docker"
ENV PATH="/flutter/bin:${PATH}"

# Running `flutter config --no-analytics` downloads the Dart SDK and
# disables analytics tracking – which we always want
# `d36e2f6191` maps to alpha release 0.0.11 @ June 22, 2017
#    We hard wire the SHA to ensure Docker rebuilds
RUN git clone -b alpha https://github.com/flutter/flutter.git && \
  cd flutter && \
  git reset d36e2f6191 --hard && \
  flutter config --no-analytics

WORKDIR /app

ADD pubspec.* /app/
RUN pub get
ADD . /app
RUN pub get --offline

ENTRYPOINT ["/usr/bin/dart", "--checked", "bin/main.dart"]
