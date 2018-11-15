require 'date'
require 'open-uri'
require 'twitter'
require 'fileutils'
require 'pry'

# Twitter image
class ImageCrawler
  attr_reader :client, :screen_name
  private :client, :screen_name

  def initialize(client:, screen_name:, dir_path: DIR_PATH)
    @client = client
    @screen_name = screen_name
    @dir_path = dir_path
  end

  def crawl(range:, count: 20)
    since_day = range.begin.strftime('%Y-%m-%d_00:00:00_JST')
    until_day = range.end.strftime('%Y-%m-%d_00:00:00_JST')
    client.search('', from: screen_name, since: since_day, until: until_day, filter: :images, exclude: :retweets, tweet_mode: :extended, lang: :ja).map do |tweet|
      next unless tweet.media?

      tweet.media.map(&:media_uri_https).map(&:to_s).each do |uri|
        download(uri: uri, file_name: uri.split('/').last)
      end
    end
  end

  private

  def download(uri:, file_name:)
    FileUtils.mkdir_p(dir_path) unless Dir.exist?(dir_path)
    Kernel.open("#{uri}:large") do |image|
      File.open("#{dir_path}/#{file_name}", 'wb') do |file|
        file.puts image.read
      end
    end
  end

  def dir_path
    "#{@dir_path}/#{screen_name}"
  end
end

IRIS_TWITTER_SCRREN_NAMES = %w[iris_y_saki iris_s_yu iris_a_himi iris_k_miyu iris_w_yuki iris_s_azuki].freeze
DIR_PATH = './images'.freeze

def main
  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
    config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  end

  IRIS_TWITTER_SCRREN_NAMES.each do |screen_name|
    today = Time.now.to_date
    yesterday = today.prev_day
    ImageCrawler.new(client: client, screen_name: screen_name).crawl(range: yesterday..today, count: 100)
  end
end

main
