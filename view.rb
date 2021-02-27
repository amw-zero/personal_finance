require 'erb'

class ErbRenderer
  def initialize(view)
    @view = view
  end

  def render
    rhtml = ERB.new(@view.template)
    rhtml.result(@view.get_binding)
  end
end

module View
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

  def form_action(interaction)
    case interaction[:type]
    when :create
      'POST'
    end
  end

  def form_field(interaction, field_name)
    field = interaction[:fields].find { |f| f[:name] == field_name }
    type = case field[:type]
          when :string
            'text'
          when :decimal
            'number'
          when :date
            'date'
          end

    
    input = case field[:type]
            when :decimal
              %{ <input class="input" type="#{type}" name="#{field_name}" step="0.01" /> }
            else
              %{ <input class="input" type="#{type}" name="#{field_name}" /> }
            end


    %{ 
      <div class="field">
        <label class="label" for="#{field_name}">#{field_name}</label>
        #{input}
      </div>
     }
  end

  def get_binding
    binding
  end

  def render(view)
    ErbRenderer.new(view).render
  end
end