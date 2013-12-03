#!/usr/local/bin/ruby -rubygems

require 'sinatra'
require 'rethinkdb'
require 'net/http'
require 'dotenv'

# Load the env
Dotenv.load

CONFIG = {
  :host   => ENV['RDB_HOST'], 
  :port   => ENV['RDB_PORT'],
  :db     => ENV['RDB_DB'],
  :table  => ENV['RDB_TABLE'],
  :user   => ENV['PASTE_USER'],
  :pass   => ENV['PASTE_PASS']
}

puts CONFIG[:host]

r = RethinkDB::RQL.new

use Rack::Auth::Basic, "Authorization Required" do |username, password|
  username == CONFIG[:user] and password == CONFIG[:pass]
end

configure do
  set :db, CONFIG[:db]
  connection = RethinkDB::Connection.new(:host => CONFIG[:host], :port => CONFIG[:port])
  begin
    r.db_create(CONFIG[:db]).run(connection)
    r.db(CONFIG[:db]).table_create(CONFIG[:table]).run(connection)
  rescue RethinkDB::RqlRuntimeError => err
    puts "Database `#{CONFIG[:db]}` and table `#{CONFIG[:table]}` already exist."
  ensure
    connection.close
  end
end

before do
  begin
    @rdb_connection = r.connect(:host => CONFIG[:host], :port => CONFIG[:port], :db => CONFIG[:db])
  rescue Exception => err
    halt 501, 'Cannot connect to database'
  end
end

after do
  @rdb_connection.close if @rdb_connection
end

get '/' do
  @paste = {}
  erb :new
end

post '/' do
  @id = ([*('A'..'Z'),*('0'..'9')]-%w(0 1 I O)).sample(5).join
  
  @paste = {
    :id  => "#{@id}",
    :body => params[:paste_body],
    :lang => (params[:paste_lang] || 'text').downcase,
  }
  
  if @paste[:body].empty?
    erb :new
  end

  @paste[:created_at] = Time.now.to_i
  @paste[:formatted_body] = pygmentize(@paste[:body], @paste[:lang])

  result = r.table(CONFIG[:table]).insert(@paste).run(@rdb_connection)

  if result['inserted'] == 1
    redirect "/#{@id}"
  else
    redirect '/'
  end
end

get '/:id' do
  @id = params[:id]
  @paste = r.table(CONFIG[:table]).get(@id).run(@rdb_connection)
  if @paste
    @number_of_lines_to_show = @paste['formatted_body'].lines.count - 1
    erb :show
  else
    redirect '/'
  end
end

helpers do
  def languages
    ['HTML', 'Javascript', 'CSS', 'PHP', 'ERB', 'Ruby', 'Objective-C']
  end
  
  def pygmentize(code, lang)
    url = URI.parse 'http://pygments.appspot.com/'
    options = {'lang' => lang, 'code' => code}
    begin
      Net::HTTP.post_form(url, options).body
    rescue
      "<pre>#{code}</pre>"
    end
  end
  
  def distance_of_time_in_words(time)
    minutes = (Time.new.to_i - time.to_i).floor / 60
    case
      when minutes < 1
        "less than a minute"
      when minutes < 2
        "about a minute"
      when minutes < 50
        "#{minutes} minutes"
      when minutes < 90
        "about an hour"
      when minutes < 1080
        "#{(minutes / 60.to_f).ceil} hours"
      when minutes < 2160
        "1 day"
      else
        "#{(minutes / 1440).round} days"
    end
  end
end