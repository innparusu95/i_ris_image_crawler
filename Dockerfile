FROM ruby:2.5
WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY ./main.rb .

CMD ["./main.rb"]
