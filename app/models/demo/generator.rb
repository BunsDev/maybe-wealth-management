class Demo::Generator
  COLORS = %w[#e99537 #4da568 #6471eb #db5a54 #df4e92 #c44fe9 #eb5429 #61c9ea #805dee #6ad28a]

  def initialize
    @family = reset_family!
  end

  def reset_and_clear_data!
    clear_data!
    create_user!

    puts "user reset"
  end

  def reset_data!
    clear_data!
    create_user!

    puts "user reset"

    create_tags!
    create_categories!
    create_merchants!

    puts "tags, categories, merchants created"

    create_credit_card_account!
    create_checking_account!
    create_savings_account!

    create_investment_account!
    create_house_and_mortgage!
    create_car_and_loan!

    puts "accounts created"

    family.sync

    puts "balances synced"
    puts "Demo data loaded successfully!"
  end

  private

    attr_reader :family

    def reset_family!
      family_id = "d99e3c6e-d513-4452-8f24-dc263f8528c0" # deterministic demo id

      family = Family.find_by(id: family_id)
      family.destroy! if family

      Family.create!(id: family_id, name: "Demo Family").tap(&:reload)
    end

    def clear_data!
      ExchangeRate.destroy_all
    end

    def create_user!
      family.users.create! \
        email: "user@maybe.local",
        first_name: "Demo",
        last_name: "User",
        password: "password"
    end

    def create_tags!
      [ "Trips", "Emergency Fund", "Demo Tag" ].each do |tag|
        family.tags.create!(name: tag)
      end
    end

    def create_categories!
      categories = [ "Income", "Food & Drink", "Entertainment", "Travel",
                    "Personal Care", "General Services", "Auto & Transport",
                    "Rent & Utilities", "Home Improvement", "Shopping" ]

      categories.each do |category|
        family.categories.create!(name: category, color: COLORS.sample)
      end
    end

    def create_merchants!
      merchants = [ "Amazon", "Starbucks", "McDonald's", "Target", "Costco",
                   "Home Depot", "Shell", "Whole Foods", "Walgreens", "Nike",
                   "Uber", "Netflix", "Spotify", "Delta Airlines", "Airbnb", "Sephora" ]

      merchants.each do |merchant|
        family.merchants.create!(name: merchant, color: COLORS.sample)
      end
    end

    def create_credit_card_account!
      cc = family.accounts.create! \
        accountable: CreditCard.new,
        name: "Chase Credit Card",
        balance: 2300,
        institution: family.institutions.find_or_create_by(name: "Chase")

      50.times do
        merchant = random_family_record(Merchant)
        create_transaction! \
          account: cc,
          name: merchant.name,
          amount: Faker::Number.positive(to: 200),
          tags: [ tag_for_merchant(merchant) ],
          category: category_for_merchant(merchant),
          merchant: merchant
      end

      5.times do
        create_transaction! \
          account: cc,
          amount: Faker::Number.negative(from: -1000),
          name: "CC Payment"
      end
    end

    def create_checking_account!
      checking = family.accounts.create! \
        accountable: Depository.new,
        name: "Chase Checking",
        balance: 15000,
        institution: family.institutions.find_or_create_by(name: "Chase")

      10.times do
        create_transaction! \
          account: checking,
          name: "Expense",
          amount: Faker::Number.positive(from: 100, to: 1000)
      end

      10.times do
        create_transaction! \
          account: checking,
          amount: Faker::Number.negative(from: -2000),
          name: "Income",
          category: income_category
      end
    end

    def create_savings_account!
      savings = family.accounts.create! \
        accountable: Depository.new,
        name: "Demo Savings",
        balance: 40000,
        subtype: "savings",
        institution: family.institutions.find_or_create_by(name: "Chase")

      income_category = categories.find { |c| c.name == "Income" }
      income_tag = tags.find { |t| t.name == "Emergency Fund" }

      20.times do
        create_transaction! \
          account: savings,
          amount: Faker::Number.negative(from: -2000),
          tags: [ income_tag ],
          category: income_category,
          name: "Income"
      end
    end

    def create_investment_account!
      account = family.accounts.create! \
        accountable: Investment.new,
        name: "Robinhood",
        balance: 100000,
        institution: family.institutions.find_or_create_by(name: "Robinhood")

      create_valuation!(account, 2.years.ago.to_date, 60000)
      create_valuation!(account, 1.year.ago.to_date, 70000)
      create_valuation!(account, 3.months.ago.to_date, 92000)
    end

    def create_house_and_mortgage!
      house = family.accounts.create! \
        accountable: Property.new,
        name: "123 Maybe Way",
        balance: 560000

      create_valuation!(house, 3.years.ago.to_date, 520000)
      create_valuation!(house, 2.years.ago.to_date, 540000)
      create_valuation!(house, 1.years.ago.to_date, 550000)

      family.accounts.create! \
        accountable: Loan.new,
        name: "Mortgage",
        balance: 495000
    end

    def create_car_and_loan!
      family.accounts.create! \
        accountable: Vehicle.new,
        name: "Honda Accord",
        balance: 18000

      family.accounts.create! \
        accountable: Loan.new,
        name: "Car Loan",
        balance: 8000
    end

    def create_transaction!(attributes = {})
      entry_attributes = attributes.except(:category, :tags, :merchant)
      transaction_attributes = attributes.slice(:category, :tags, :merchant)

      entry_defaults = {
        date: Faker::Number.between(from: 0, to: 90).days.ago.to_date,
        currency: "USD",
        entryable: Account::Transaction.new(transaction_attributes)
      }

      Account::Entry.create! entry_defaults.merge(entry_attributes)
    end

    def create_valuation!(account, date, amount)
      Account::Entry.create! \
        account: account,
        date: date,
        amount: amount,
        currency: "USD",
        entryable: Account::Valuation.new
    end

    def random_family_record(model)
      family_records = model.where(family_id: family.id)
      model.offset(rand(family_records.count)).first
    end

    def category_for_merchant(merchant)
      mapping = {
        "Amazon" => "Shopping",
        "Starbucks" => "Food & Drink",
        "McDonald's" => "Food & Drink",
        "Target" => "Shopping",
        "Costco" => "Food & Drink",
        "Home Depot" => "Home Improvement",
        "Shell" => "Auto & Transport",
        "Whole Foods" => "Food & Drink",
        "Walgreens" => "Personal Care",
        "Nike" => "Shopping",
        "Uber" => "Auto & Transport",
        "Netflix" => "Entertainment",
        "Spotify" => "Entertainment",
        "Delta Airlines" => "Travel",
        "Airbnb" => "Travel",
        "Sephora" => "Personal Care"
      }

      categories.find { |c| c.name == mapping[merchant.name] }
    end

    def tag_for_merchant(merchant)
      mapping = {
        "Delta Airlines" => "Trips",
        "Airbnb" => "Trips"
      }

      tag_from_merchant = tags.find { |t| t.name == mapping[merchant.name] }

      tag_from_merchant || tags.find { |t| t.name == "Demo Tag" }
    end

    def merchants
      @merchants ||= family.merchants
    end

    def categories
      @categories ||= family.categories
    end

    def tags
      @tags ||= family.tags
    end

    def income_tag
      @income_tag ||= tags.find { |t| t.name == "Emergency Fund" }
    end

    def income_category
      @income_category ||= categories.find { |c| c.name == "Income" }
    end
end
