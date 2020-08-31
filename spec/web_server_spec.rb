ENV['APP_ENV'] = 'test'

require_relative '../web_server/server'
require 'rack/test'

describe 'The Personal Finance Web Server' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  it 'works' do
    get '/'

    expect(last_response).to be_ok
  end
end