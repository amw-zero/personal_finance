class DataInteractor
  def initialize(persistence)
    @persistence = persistence
  end

  def relation(name)
    @persistence.relation_of(name)
  end

  def to_models(relation, model_klass)
    #      log relation.to_sql if relation.is_a?(Bmg::Sql::Relation)
    case model_klass.to_s
    when 'PlannedTransaction'
      relation.map do |data|
        data[:currency] = data[:currency].to_sym
        model_klass.new(data)
      end
    when 'TransactionTagSet'
      relation.map do |data|
        data[:tags] = data[:tags].split(',')
        model_klass.new(data)
      end
    else
      relation.map do |data|
        model_klass.new(data)
      end
    end
  end
end