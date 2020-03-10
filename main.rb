#frozen_string_literal: true

require 'date'
require 'open-uri'
require 'twitter'
require 'aws-sdk'

class ImageCrawler
  attr_reader :client, :screen_name
  private :client, :screen_name

  def initialize(client:, screen_name:, dir_path:)
    @client = client
    @screen_name = screen_name
    @dir_path = dir_path
    @bucket = Aws::S3::Resource.new.bucket(ENV["AWS_S3_BUCKET"])
  end

  def crawl(range:)
    since_day = range.begin.strftime('%Y-%m-%d_00:00:00_JST')
    until_day = range.end.strftime('%Y-%m-%d_00:00:00_JST')
    client.search('', from: screen_name, since: since_day, until: until_day, filter: :images, exclude: :retweets, tweet_mode: :extended, lang: :ja).map do |tweet|
      next unless tweet.media?

      tweet.media.map(&:media_uri_https).map(&:to_s).each do |uri|
        download(uri: uri, file_name: uri.split('/').last)
        puts "download account: #{screen_name} uri:#{uri}"
      end
    end
  end

  private

    def download(uri:, file_name:)
      URI.open("#{uri}:large") do |image|
        @bucket.object("#{dir_path}/#{file_name}").put(body: image.read)
      end
    end

    def dir_path
      "#{@dir_path}/#{screen_name}"
    end
end

class ListImageCrawler
  attr_reader :client, :list_name, :range
  private :client, :list_name, :range

  def initialize(client:, list_name:, range:)
    @client = client
    @list_name = list_name
    @range = range
  end

  def crawl
    client.list_members(slug: list_name).map(&:screen_name).each do |screen_name|
      ImageCrawler.new(client: client, screen_name: screen_name, dir_path: list_name).crawl(range: range)
    end
  end
end

def lambda_handler(event:, context:)
  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
    config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  end

  now = Time.now
  today = now.getlocal("+09:00").to_date
  yesterday = today.prev_day

  %w[i-ris nijimasu].each do |list_name|
    ListImageCrawler.new(client: client, list_name: list_name, range: yesterday..today).crawl
  end
end
