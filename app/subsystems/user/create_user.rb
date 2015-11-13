module User
  class CreateUser
    lev_routine express_output: :user

    uses_routine OpenStax::Accounts::FindOrCreateAccount,
      translations: { outputs: { type: :verbatim } },
      as: :find_or_create_account

    protected

    def exec(account_id: nil, exchange_identifiers: nil,
             email: nil, username: nil, password: nil,
             first_name: nil, last_name: nil, full_name: nil, title: nil)
      raise ArgumentError, 'Requires either an email, a username or an account_id' \
        if email.nil? && username.nil? && account_id.nil?

      account_id ||= find_or_create_account_id(
        email: email, username: username, password: password,
        first_name: first_name, last_name: last_name,
        full_name: full_name, title: title
      )

      user = ::User::User.create(
        exchange_read_identifier: (exchange_identifiers || new_identifiers).read,
        exchange_write_identifier: (exchange_identifiers || new_identifiers).write,
        account_id: account_id
      )

      if user.to_model.valid?
        outputs.user = user
      else
        fatal_error(code: :could_not_create_user,
                    message: user.to_model.errors.first.join(' ').capitalize)
      end
    end

    private

    def new_identifiers
      @identifiers ||= OpenStax::Exchange.create_identifiers
    end

    def find_or_create_account_id(attrs)
      run(:find_or_create_account, attrs).outputs.account.id
    end
  end
end
