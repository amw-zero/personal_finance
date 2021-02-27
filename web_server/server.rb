# frozen_string_literal: true

require 'sinatra'
require 'ostruct'
require_relative '../personal_finance'
require_relative '../postgres/postgres_persistence'
require_relative '../view'

application = PersonalFinance::Application.new(log_level: ENV['LOG_LEVEL'], persistence: PostgresPersistence.new)

get '/' do
  redirect '/transactions'
end

application.interactions.each_value do |interaction|
  method = {
    create: :post,
    view: :get,
    delete: :delete,
  }[interaction[:type]]

  send(method, interaction[:name]) do
    result = application.execute(interaction, params)

    # Returning an Interaction redirects to it
    if result.is_a?(Hash)
      redirect result[:name]
    else
      ErbRenderer.new(result).render
    end
  end
end

application.use_cases.each do |_name, use_case|
  use_case.endpoints.each do |endpoint|
    mutation_block = lambda do
      endpoint[:action].call(params)

      redirect endpoint[:return] || endpoint[:path]
    end

    case endpoint[:method]
    when :get
      get endpoint[:path] do
        data = endpoint[:action].call(params)

        @page = endpoint[:page] || use_case.name

        erb use_case.name, locals: {
          data: data,
          accounts: application.accounts,
          params: params
        }
      end
    when :post
      post(endpoint[:path], &mutation_block)
    when :delete
      delete(endpoint[:path], &mutation_block)
    end
  end
end