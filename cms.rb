require "sinatra"
require "sinatra/reloader" if development?
# require "sinatra/content_for"
require "tilt/erubis"
require "redcarpet"
require "yaml"

require_relative "user"

configure do
  enable :sessions
  set :session_secret, "secret" ## normally wouldn't store env variable in code
  # set :erb, :escape_html => true
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def credentials_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/.users.yml", __FILE__)
  else
    File.expand_path("../.users.yml", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

def incorrect_filetype?(filename)
  ext = File.extname(filename)
  !(ext == ".txt" || ext == ".md")
end

def create_user(user_name, pass_word)
  user = User.new(user_name, pass_word)
  accounts = YAML.load_file(credentials_path)
  accounts << user
  File.open(credentials_path, "w") { |file| file.write(accounts.to_yaml) }
end

def valid_authentication?(user_name, pass_word)
  accounts = YAML.load_file(credentials_path)
  user_found = accounts.index { |user| user.username == user_name }
  !!user_found && accounts[user_found].check_password(pass_word)
end

def username_already_exists?(user_name)
  accounts = YAML.load_file(credentials_path)
  user_found = accounts.index { |user| user.username == user_name }
  !!user_found
end

def signed_in?
  !!session[:username]
end

def require_signed_in_user
  if !signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map { |path| File.basename(path) }
  erb :index
end

get "/new" do
  require_signed_in_user

  erb :new_file
end

post "/create" do
  require_signed_in_user

  @filename = params[:filename].to_s

  if @filename.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new_file
  elsif incorrect_filetype?(@filename)
    session[:message] = "File must be .txt or .md."
    status 422
    erb :new_file
  else
    file_path = File.join(data_path, @filename)
    File.write(file_path, "")
    session[:message] = "#{@filename} has been created."
    redirect "/"
  end
end

get "/:filename" do
  file_path = File.join(data_path, params[:filename])

  if !File.exist?(file_path)
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  else
    load_file_content(file_path)
  end
end

get "/:filename/edit" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  if !File.exist?(file_path)
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  else
    @filename = params[:filename]
    @content = File.read(file_path)
    erb :edit
  end
end

post "/:filename" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.write(file_path, params[:new_content])
  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  require_signed_in_user

  file_path = File.join(data_path, params[:filename])

  File.delete(file_path)
  session[:message] = "#{params[:filename]} has been deleted."
  redirect "/"
end

get "/users/signin" do
  redirect "/" if session[:username]
  erb :login
end

post "/users/signin" do
  @username = params[:username].to_s.strip
  password = params[:password].to_s.strip

  if !valid_authentication?(@username, password)
    session[:message] = "Invalid Credentials."
    status 422
    erb :login
  else
    session[:username] = @username
    session[:message] = "Welcome!"
    redirect "/"
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/users/new" do
  redirect "/" if session[:username]
  erb :new_user
end

post "/users/create" do
  @username = params[:username].to_s.strip
  password = params[:password].to_s.strip

  if @username.size == 0 || password.size == 0
    session[:message] = "A username and password is required."
    status 422
    erb :new_user
  elsif username_already_exists?(@username)
    session[:message] = "Invalid username, #{@username} is already taken."
    status 422
    erb :new_user
  else
    create_user(@username, password)
    session[:username] = @username
    session[:message] = "Account for #{@username} has been created."
    redirect "/"
  end
end
