require_relative 'postgres'

# Store relations in postgres
class PostgresPersistence
  def initialize
    @db = Sequel.connect(Postgres::SERVER_URL)
  end

  def relation
    Bmg.sequel(:people, @db)
  end

  def persist(relation, data)
    relation = Bmg.sequel(relation, @db)
    relation.insert(data)
  end

  def relation_of(rel_name)
    Bmg.sequel(rel_name, @db)
  end
end
