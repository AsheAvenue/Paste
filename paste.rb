# encoding: UTF-8

require 'sinatra'
require 'net/http'
require 'dotenv'
require 'sequel'

# Load the .env file
Dotenv.load

# Set up the config values
CONFIG = {
  :user   => ENV['PASTE_USER'],
  :pass   => ENV['PASTE_PASS'],
  :mysql_host   => ENV['MYSQL_HOST'],
  :mysql_user   => ENV['MYSQL_USER'],
  :mysql_pass   => ENV['MYSQL_PASS'],
  :mysql_db     => ENV['MYSQL_DB'],
  :mysql_table  => ENV['MYSQL_TABLE']
}

# Some basic ht auth
use Rack::Auth::Basic, "Authorization Required" do |username, password|
  username == CONFIG[:user] and password == CONFIG[:pass]
end

# Show the 'new paste' screen 
get '/' do
  id = ([*('A'..'Z'),*('0'..'9')]-%w(0 1 I O)).sample(5).join
  redirect "/#{id}"
end

# Show a paste or the edit form
get '/:id' do
  @id = params[:id]
  @paste = get_paste(@id)
  if @paste
    @exists = true
    @number_of_lines_to_show = @paste['formatted_body'].lines.count - 1
    erb :show
  else
    @paste = {}
    erb :form
  end
end

# Edit a paste
get '/:id/edit' do
  @id = params[:id]
  @paste = get_paste(@id)
  if @paste
    @editing = true
    erb :form
  else
    redirect "/#{@id}"
  end
end

# Handle updating of a paste
post '/:id' do
  @id = params[:id]
  @editing = params[:editing] != "" ? params[:editing] : nil

  if params[:paste_body].empty?
    erb :form
  else
    body = params[:paste_body]
    body.gsub!("'", %q(\\\'))
    body.force_encoding('UTF-8')
    formatted_body = pygmentize(params[:paste_body], params[:paste_lang].downcase)
    formatted_body.gsub!("'", %q(\\\'))
    formatted_body.force_encoding('UTF-8')
    db = Sequel.connect("mysql://#{CONFIG[:mysql_user]}:#{CONFIG[:mysql_pass]}@#{CONFIG[:mysql_host]}/#{CONFIG[:mysql_db]}")
    if @editing
      db.run("UPDATE pastes SET body = '#{body}', formatted_body = '#{formatted_body}', lang = '#{(params[:paste_lang] || 'text').downcase}', updated_at = #{Time.now.to_i} WHERE id = '#{@id}' ")
    else
      db.run("INSERT INTO pastes (id, body, formatted_body, lang, created_at) VALUES('#{@id}', '#{body}', '#{formatted_body}', '#{(params[:paste_lang] || 'text').downcase}', #{Time.now.to_i}) ")
    end
    db.disconnect
    redirect "/#{@id}"
  end
end

# Private functions used herein.
helpers do
  
  def get_paste(id)
    db = Sequel.connect("mysql://#{CONFIG[:mysql_user]}:#{CONFIG[:mysql_pass]}@#{CONFIG[:mysql_host]}/#{CONFIG[:mysql_db]}")
    db["SELECT * FROM pastes where id = '#{id}'"].each do |row|
      @paste = {}
      @paste['id'] = row[:id]
      @paste['body'] = row[:body]
      @paste['formatted_body'] = row[:formatted_body]
      @paste['lang'] = row[:lang]
      @paste['created_at'] = row[:created_at]
      @paste['updated_at'] = row[:updated_at]
    end
    db.disconnect
    
    @paste
  end
  
  # The languages visible in the drop-down and send to the pygments service
  def languages
    ['HTML', 'Javascript', 'CSS', 'PHP', 'ERB', 'Ruby', 'Objective-C']
  end
  
  # Use the pygments web service
  def pygmentize(code, lang)
    url = URI.parse 'http://pygments.simplabs.com/'
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