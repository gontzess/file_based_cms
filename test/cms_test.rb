ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_viewing_text_document
    create_document "history.txt", "Ruby 0.95 released"

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 0.95 released"
  end

  def test_viewing_markdown_document
    create_document "about.md", "#Ruby is..."

    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_document_does_not_exist
    get "/oopsnotrealfile.ext"
    assert_equal 302, last_response.status
    assert_equal "oopsnotrealfile.ext does not exist.", session[:message]
  end

  def test_viewing_edit_document_form
    create_document "changes.txt"

    get "/changes.txt/edit"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Edit content of changes.txt:"
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_edit_document_form_does_not_exist
    get "/oopsnotrealfile.ext/edit", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "oopsnotrealfile.ext does not exist.", session[:message]
  end

  def test_submitting_edit_document_form_success
    create_document "changes.txt", "original text"

    post "/changes.txt", {new_content: "test changes"}
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    post "changes.txt", {new_content: "test changes"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "test changes"
  end

  def test_viewing_new_document_form
    get "/new"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Add a new document:"
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_submitting_new_document_form_success
    post "/create", {filename: ""}
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    post "/create", {filename: ""}, admin_session
    assert_equal 422, last_response.status

    post "/create", {filename: "bad.ext"}
    assert_equal 422, last_response.status
    assert_includes last_response.body, "File must be .txt or .md."

    post "/create", {filename: "test.md"}
    assert_equal 302, last_response.status
    assert_equal "test.md has been created.", session[:message]

    get "/"
    assert_includes last_response.body, %q(href="/test.md")

    get "/test.md"
    assert_equal 200, last_response.status
  end

  def test_deleting_document_success
    create_document "test.txt"

    post "/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]

    post "/test.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "test.txt has been deleted.", session[:message]

    get "/"
    assert_equal 200, last_response.status
    refute_includes last_response.body, %q(href="/test.txt")
  end

  def test_viewing_login_form
    get "/users/signin"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_viewing_login_form_already_loggedin
    post "/users/signin", username: "admin", password: "secret"

    get "/users/signin"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
  end

  def test_signin_with_correct_credentials
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin."
  end

  def test_signin_with_bad_credentials
    post "/users/signin", username: "baduser", password: "wrongpass"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid Credentials."
  end

  def test_logout
    get "/", {}, {"rack.session" => { username: "admin" } }
    assert_includes last_response.body, "Signed in as admin."

    post "/users/signout"
    assert_equal 302, last_response.status
    assert_equal "You have been signed out.", session[:message]

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end

  def test_viewing_new_user_form
    get "/users/new"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
    assert_nil session[:username]
  end

  def test_submitting_new_user_form_success
    original_accounts = YAML.load_file(credentials_path)

    post "/users/create", username: "tester", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Account for tester has been created.", session[:message]
    assert_equal "tester", session[:username]

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as tester."

    accounts = YAML.load_file(credentials_path)
    assert_equal "tester", accounts[-1].username
    refute_equal "secret", accounts[-1].password_hash
    assert_equal true, accounts[-1].password_hash.is_a?(BCrypt::Password)

    File.open(credentials_path, "w") do |file|
      file.write(original_accounts.to_yaml)
    end
  end

  def test_submitting_new_user_form_empty_field
    post "/users/create", username: "fred", password: ""
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "A username and password is required."
  end

  def test_submitting_new_user_form_username_taken
    post "/users/create", username: "admin", password: "secret"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "is already taken."
  end
end
