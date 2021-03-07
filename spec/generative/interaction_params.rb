def interaction_params(interaction)
  interaction[:fields].map do |field|
    value = case field[:type]
            when :decimal
              (any integers).to_f
            when :string
              any strings
            when :date
              '2020-01-03'
            end

    [field[:name], value]
  end.to_h
end