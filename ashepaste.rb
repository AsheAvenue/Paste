#!/usr/local/bin/ruby -rubygems

require 'sinatra'
require 'rethinkdb'
require 'net/http'

RDB_CONFIG = {
  :host   => ENV['RDB_HOST']  || 'db.labs.asheavenue.com', 
  :port   => ENV['RDB_PORT']  || 28015,
  :db     => ENV['RDB_DB']    || 'ashepaste',
  :table  => ENV['RDB_TABLE'] || 'pastes'
}

r = RethinkDB::RQL.new
  
configure do
  set :db, RDB_CONFIG[:db]
  connection = RethinkDB::Connection.new(:host => RDB_CONFIG[:host], :port => RDB_CONFIG[:port])
  begin
    r.db_create(RDB_CONFIG[:db]).run(connection)
    r.db(RDB_CONFIG[:db]).table_create(RDB_CONFIG[:table]).run(connection)
  rescue RethinkDB::RqlRuntimeError => err
    puts "Database `#{RDB_CONFIG[:db]}` and table `#{RDB_CONFIG[:table]}` already exist."
  ensure
    connection.close
  end
end

before do
  begin
    @rdb_connection = r.connect(:host => RDB_CONFIG[:host], :port => RDB_CONFIG[:port], :db => RDB_CONFIG[:db])
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

  result = r.table(RDB_CONFIG[:table]).insert(@paste).run(@rdb_connection)

  if result['inserted'] == 1
    redirect "/#{@id}"
  else
    redirect '/'
  end
end

get '/:id' do
  @id = params[:id]
  @paste = r.table(RDB_CONFIG[:table]).get(@id).run(@rdb_connection)
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
    Net::HTTP.post_form(url, options).body
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