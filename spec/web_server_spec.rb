# frozen_string_literal: true

ENV['APP_ENV'] = 'test'

require_relative '../web_server/server'
require 'rack/test'

describe 'The Personal Finance Web Server' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  skip 'can render the home page' do
    get '/'

    expect(last_response).to be_ok
  end

  skip 'can create a person' do
    post '/people', 'name' => 'Test Person'

    expect(last_response.status).to eq(302)
    #    expect(last_response.headers['Location']).to eq(app.base_url)
  end
end
