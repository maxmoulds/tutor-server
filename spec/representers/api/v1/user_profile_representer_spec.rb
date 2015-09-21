require 'rails_helper'

RSpec.describe Api::V1::TaskPlanWithDetailedStatsRepresenter, type: :representer do


  let(:user)           { FactoryGirl.build(:user_profile_profile) }
  let(:representation) { Api::V1::UserProfileRepresenter.new(user).as_json }

  it "generates a JSON representation of a user" do
    expect(representation).to eq(
      "name" => user.name,
      'is_admin' => false,
      'profile_url' => Addressable::URI.join(
        OpenStax::Accounts.configuration.openstax_accounts_url,
        '/profile').to_s
    )
  end

end
