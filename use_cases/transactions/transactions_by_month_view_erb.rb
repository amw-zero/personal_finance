<div class="block">
  <div class="card">
    <header class="card-header">
      <p class="card-header-title">
      Expense Variance
      </p>
    </header>
    <div class="card-content">
      <div class="content">
        <% periods
          .group_by { |period| period.transactions.sum.round(2) }
          .sort_by { |(net, _)| net }
          .each do |net, periods| %>
            <div>
              <strong><%= net %></strong> 
              <ul>
                <% periods.map(&:date_range).each do |range| %>
                  <li><%= display_date_range(range) %></li>
                <% end %>
              </ul>
            </div>
            <br>
        <% end %>
      </div>
    </div>
  </div>
</div>
<% periods.each do |period| %>
  <div class="block">
    <div class="card">
      <header class="card-header">
        <p class="card-header-title">
          <%= display_date_range(period.date_range) %>
        </p>
      </header>
      <div class="card-content">
        <div class="content">
          <table class="table is-fullwidth">
            <thead>
              <th>Total Expenses</th>
            </thead>
            <tbody>
              <tr>
                <td><%= -1 * period.transactions.sum %></td>
              </tr>
            </tbody>
          </table>

          <table class="table is-fullwidth is-striped">
            <thead>
              <th>Name</th>
              <th>Amount</th>
              <th>Date</th>
            </thead>
            <tbody>
              <% period.transactions.transactions.each do |transaction| %>
                <tr>
                  <td><%= transaction.name %></td>
                  <td><%= transaction.amount %></td>
                  <td><%= transaction.date %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
<% end %>