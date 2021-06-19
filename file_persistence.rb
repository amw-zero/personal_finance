# frozen_string_literal: true
require 'json'

# Store relations in a file
class FilePersistence
  STATE = '/Users/alexweisberger/.personal_finance/state'

  def initialize
    unless File.exists?(STATE)
      system("mkdir #{File.dirname(STATE)}")
      system("touch #{STATE}")
      system("echo {} >> #{STATE}")
    end

    @ids = Hash.new(1)
  end

  def persist(relation, data)
    state = read_state
    rel = state[relation]
    data[:id] = @ids[relation]
    @ids[relation] += 1
    rel << data
    state[relation] = rel

    write_state!(state)
  end

  def delete(relation, to_delete)
    data = read_state
    ids = to_delete.map { |d| d[:id] }

    data[relation].reject! { |d| ids.include?(d[:id]) }

    write_state!(data)
  end

  def relation_of(rel_name)
    Bmg::Relation.new(read_state[rel_name] || [])
  end

#  private

  def read_state
    data = JSON.parse(File.read(STATE)).transform_keys(&:to_sym)
    data.transform_values! { |r| r.each { |d| d.transform_keys!(&:to_sym) } }

    Hash.new([]).merge(data)
  end

  def write_state!(d)
    File.open(STATE, 'w') do |fp|
      fp.puts(JSON.generate(d))
    end
  end
end
