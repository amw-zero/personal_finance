# require_relative '../test_application'
# require_relative './actions'
# require_relative './interaction_params'
# # require_relative '../../view'

# describe 'Viewing Transactions within a Period' do
#   include Hypothesis
#   include Hypothesis::Possibilities


#   # HATEOAS actions - hav each interaction return a list of next interactions. Test traverses graph randomly. New behavior is just new properties
#   specify do

#     # interaction = (Interaction, State) -> ([Interaction], State)
#     root_interaction = test_application.interactions[:root]
#     to_execute = [root_interaction]
#     100.times do 
#       interaction = to_execute.pop
#       next_interactions = test_application.execute(interaction)

#       to_execute << any(element_of)
#     end
#   end
# end