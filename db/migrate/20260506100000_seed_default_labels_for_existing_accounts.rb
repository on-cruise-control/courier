class SeedDefaultLabelsForExistingAccounts < ActiveRecord::Migration[7.0]
  def up
    Account.find_each do |account|
      Account::DEFAULT_LABELS.each do |attrs|
        account.labels.find_or_create_by(title: attrs[:title]) do |label|
          label.color = attrs[:color]
          label.description = attrs[:description]
          label.show_on_sidebar = true
        end
      end
    end
  end

  def down; end
end
