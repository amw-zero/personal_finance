# frozen_string_literal: true

require 'sinatra'
require 'ostruct'
require_relative '../personal_finance'
require_relative '../postgres/postgres_persistence'
require_relative '../view'

application = PersonalFinance::Application.new(log_level: ENV['LOG_LEVEL'], persistence: PostgresPersistence.new)

# get '/' do
#   @people = application.people
#   @accounts = application.accounts
#   @cash_flow = if params[:account]
#                  application.cash_flow(params[:account].to_i)
#                else
#                  application.all_transactions.transactions
#                end
#   @tag_index = application.tag_index
#   @is_tag_intersection = params[:intersection] == 'on'
#   @tagged_transactions = if params[:transaction_tag]
#                            application.transactions_for_tags(
#                              params[:transaction_tag],
#                              @tag_index,
#                              intersection: params[:intersection] == 'on'
#                            )
#                          elsif params[:transaction_tag_set]
#                            application.transactions_for_tag_sets(params[:transaction_tag_set])
#                          end

#   @tag_sets = application.all_transaction_tag_sets
#   @page = :dashboard

#   erb :home
# end

get '/' do
  redirect '/transactions'
end

get '/transactions/create' do
  @accounts = application.accounts
  erb :transaction_form
end

get '/transactions/:id/tags/create' do
  @transaction = application.all_transactions.transactions.find { |t| t.id == params[:id].to_i }
  erb :transaction_tag_form
end

application.interactions.values.each do |interaction|
  execute = -> do
    ErbRenderer.new(application.execute(interaction, params)).render
  end

  method = {
    create: :post,
    view: :get
  }[interaction[:type]]

  send(method, interaction[:name], &execute)
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

helpers do
  def display_date_range(range)
    start = range.begin
    ending = range.end - 1

    fmt = ->(d) { d.strftime('%b %e, %Y') }

    "#{fmt.call(range.begin)} - #{fmt.call(range.end - 1)}"
  end

  def display_recurrence_rule(rule)
    parts = rule.split(';')

    values = parts.reduce({}) do |values, param|
      name, value = param.split('=')
      values[name] = value

      values
    end

    days = {
      'MO' => 'Monday',
      'TU' => 'Tuesday',
      'WE' => 'Wednesday',
      'TH' => 'Thursday',
      'FR' => 'Friday',
      'SA' => 'Saturday',
      'SU' => 'Sunday'
    }

    frequency = values['FREQ']

    if values.keys.include?('INTERVAL')
      freq_str, on = case frequency
                 when 'MONTHLY'
                  if frequency == 1
                    ['month', values['BYMONTHDAY']]
                  else
                    ['months', values['BYMONTHDAY']]
                  end
                 when 'WEEKLY'
                   if frequency == 1
                    ['week', values['BYDAY']]
                   else
                    ['weeks', days[values['BYDAY']]]
                   end
                 end
      "Every #{values['INTERVAL']} #{freq_str} on #{on}"
    else
      freq_str, on = case frequency
                        when 'MONTHLY'
                          ['month', values['BYMONTHDAY']]
                        when 'WEEKLY'
                          ['week', days[values['BYDAY']]]
                        end

      "Every #{freq_str} on #{on}"
    end
  end
end
