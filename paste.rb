# encoding: UTF-8

require 'sinatra'
require 'rethinkdb'
require 'net/http'
require 'dotenv'

# Load the .env file
Dotenv.load

# Set up the config values
CONFIG = {
  :host   => ENV['RDB_HOST'], 
  :port   => ENV['RDB_PORT'],
  :db     => ENV['RDB_DB'],
  :table  => ENV['RDB_TABLE'],
  :user   => ENV['PASTE_USER'],
  :pass   => ENV['PASTE_PASS']
}

# Create the Rethink object
r = RethinkDB::RQL.new

# Some basic ht auth
use Rack::Auth::Basic, "Authorization Required" do |username, password|
  username == CONFIG[:user] and password == CONFIG[:pass]
end

# When the app starts, ensure the database is set up
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

# Always each request by opening a connection to Rethink
before do
  begin
    @rdb_connection = r.connect(:host => CONFIG[:host], :port => CONFIG[:port], :db => CONFIG[:db])
  rescue Exception => err
    halt 501, 'Cannot connect to database'
  end
end

# Always finish each request by closing the Rethink connection
after do
  @rdb_connection.close if @rdb_connection
end

# Show the 'new paste' screen 
get '/' do
  @paste = {}
  erb :new
end

# Handle creation of a new paste
post '/' do
  
  # Generate a simple 5-character ID
  @id = ([*('A'..'Z'),*('0'..'9')]-%w(0 1 I O)).sample(5).join
  
  @paste = {
    :id  => "#{@id}",
    :body => params[:paste_body],
    :lang => (params[:paste_lang] || 'text').downcase,
    :created_at = Time.now.to_i
  }
  
  # Pretend we're on the 'new paste' screen if the user isn't posting a body or it's blank.
  if @paste[:body].empty?
    erb :new
  end
  
  # Get the formatted body after pygmentizing
  formatted_body = pygmentize(@paste[:body], @paste[:lang])
  formatted_body = formatted_body.force_encoding('UTF-8')
  @paste[:formatted_body] = formatted_body

  # Save the paste in the Rethink DB
  result = r.table(CONFIG[:table]).insert(@paste).run(@rdb_connection)

  # Redirect to the 'show paste' page or bounce back to the start page
  if result['inserted'] == 1
    redirect "/#{@id}"
  else
    redirect '/'
  end
end

# Show a paste
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

# Private functions used herein.
helpers do
  
  # The languages visible in the drop-down and send to the pygments service
  def languages
    ['HTML', 'Javascript', 'CSS', 'PHP', 'ERB', 'Ruby', 'Objective-C']
  end
  
  # Use the pygments web service
  def pygmentize(code, lang)
    url = URI.parse 'http://pygments.appspot.com/'
    options = {'lang' => lang, 'code' => code}
    begin
      Net::HTTP.post_form(url, options).body
    rescue
      "<pre>#{code}</pre>"
    end
  end
  
  # Replicate one of Rails' most useful features
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