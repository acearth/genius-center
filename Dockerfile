FROM ruby:2.5.3-alpine
MAINTAINER an_x an_xiaoqiang@find_me_at.slack
RUN apk add --update --no-cache build-base postgresql-dev yarn nodejs
WORKDIR /myapp
ADD . /myapp
ENV RAILS_ENV production
# NOTE: On AWS, rubygems.org works bad. Using China mirror instead(Kindly quick)
RUN bundle config mirror.https://rubygems.org https://gems.ruby-china.com
RUN bundle install --without development test
EXPOSE 3000
