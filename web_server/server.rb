# frozen_string_literal: true

require 'sinatra'
require_relative '../personal_finance'
require_relative '../file_persistence'
require_relative '../view'

application = PersonalFinance::Application.new(log_level: ENV['LOG_LEVEL'], persistence: FilePersistence.new)

application.interactions.each_value do |interaction|
  method = {
    create: :post,
    view: :get,
    delete: :delete
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
