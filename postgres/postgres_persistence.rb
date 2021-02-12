# frozen_string_literal: true

require_relative 'postgres'

# Store relations in postgres
class PostgresPersistence
  def initialize
    @db = Sequel.connect(Postgres::SERVER_URL)
  end

  def persist(relation, data)
    relation = Bmg.sequel(relation, @db)
    relation.insert(data)
  end

  def delete(relation, to_delete)
    # NOTE: Kind of stinks that the table _needs_ to have an id column to be
    # deletable.
    ids = to_delete.map { |d| d[:id] }
    @db[relation].where(id: ids).delete
  end

  def relation_of(rel_name)
    Bmg.sequel(rel_name, @db)
  end
end
