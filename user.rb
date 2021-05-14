require "bcrypt"
# require "yaml"

class User
  include BCrypt

  attr_reader :username, :password_hash

  def initialize(username, password)
    @username = username
    @password_hash = encrypt(password)
  end

  def check_password(submitted_password)
    Password.new(@password_hash) == submitted_password
  end

  # def to_yaml
  #   [self].to_yaml
  # end

  private

  def encrypt(password)
    Password.create(password)
  end
end
