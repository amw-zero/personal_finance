# Store relations in memory
class MemoryPersistence
  attr_reader :people

  def initialize
    @relations = Hash.new(Bmg::Relation.new([]))
    @ids = Hash.new(1)
  end

  def relation_of(rel_name)
    @relations[rel_name]
  end

  def delete(relation, to_delete)
    @relations[relation] = Bmg::Relation.new(@relations[relation].to_a - to_delete.to_a)
  end

  def persist(relation, data)
    data[:id] = @ids[relation]
    @ids[relation] += 1
    @relations[relation] = @relations[relation].union(Bmg::Relation.new([data]))
  end
end