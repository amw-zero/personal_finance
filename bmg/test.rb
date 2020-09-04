require 'bmg'
require 'json'

relation = Bmg::Relation.new([
  { id: 1, name: 'Test' },
  { id: 2, name: 'Other' },
  { id: 4, name: 'Other'}
])

pp relation.to_a

restricted = relation.restrict(Predicate.neq(name: 'Test'))
# puts restricted.to_sql

# puts "Group"
# pp JSON.pretty_generate(relation.group([:name, :id], :group))

pp relation.union(Bmg::Relation.new([{id: 3, name: 'Newest'}])).to_a

empty = Bmg::Relation.new([])
pp empty.union(Bmg::Relation.new([{test: 5}])).to_a

suppliers = Bmg::Relation.new([
  { sid: "S1", name: "Smith", status: 20, city: "London" },
  { sid: "S2", name: "Jones", status: 10, city: "Paris"  },
  { sid: "S3", name: "Blake", status: 30, city: "Paris"  },
  { sid: "S4", name: "Clark", status: 20, city: "London" },
  { sid: "S5", name: "Adams", status: 30, city: "Athens" }
])

by_city = suppliers
  .restrict(Predicate.gt(status: 20))
  .extend(upname: ->(t){ t[:name].upcase })
#  .summarize([:status])

pp suppliers.count
pp suppliers.page([:name, :asc], 1, page_size: suppliers.count).to_a

accounts = Bmg::Relation.new([
  { id: 1, name: 'Checking '},
  { id: 2, name: 'Savings' }
])

incomes = Bmg::Relation.new([
  { amount: 100, account_id: 2 },
  { amount: 200, account_id: 2 }
])

pp incomes.matching(accounts, { account_id: :id }).to_a
# pp incomes.group()


# new_rel = Bmg::Relation.new([], :test)
# new_rel.insert(test: 5)
# new_rel.insert(test: 6)

# pp new_rel