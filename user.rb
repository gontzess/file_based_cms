require 'bcrypt'
require 'yaml'

class User
  include BCrypt

  attr_reader :username

  def initialize(username, password)
    @username = username
    @password_hash = encrypt(password)
  end

  def check_password(submitted_password)
    Password.new(@password_hash) == submitted_password
  end

  def to_yaml
    [self].to_yaml
  end

  private

  def encrypt(password)
    Password.create(password)
  end
end
# #
# pass_word = "letmein"
# accounts = YAML.load_file(".users.yml")
# user_found = accounts.index { |usr| usr.username == "developer" }
# # p accounts.index { |user| user.username == "developer1" }
# p user_found
# p accounts[user_found].username
# # user_found && accounts[user_found].check_password(pass_word)
# p accounts[user_found].check_password(pass_word)
