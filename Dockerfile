FROM alpine:3.7
MAINTAINER Revenue Masters <support@revenuemasters.com>

ENV BUILD_PACKAGES bash curl-dev ruby-dev build-base git
ENV RUBY_PACKAGES ruby ruby-io-console ruby-bundler

# Update and install all of the required packages.
RUN apk --no-cache add nginx $BUILD_PACKAGES
RUN apk --no-cache add nginx $RUBY_PACKAGES

RUN mkdir /usr/app
WORKDIR /usr/app

COPY Gemfile /usr/app/
COPY Gemfile.lock /usr/app/
RUN bundle install
