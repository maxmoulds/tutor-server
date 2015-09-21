require 'rails_helper'

RSpec.describe Admin::UsersController do
  let!(:admin) { FactoryGirl.create :user_profile_profile,
                                    :administrator,
                                    username: 'admin',
                                    full_name: 'Administrator' }
  let!(:profile) { FactoryGirl.create :user_profile_profile,
                                      username: 'student',
                                      full_name: 'User One' }

  before { controller.sign_in(admin) }

  it 'searches users by username and full name' do
    get :index, search_term: 'STR'
    expect(assigns[:user_search].items.length).to eq 1
    expect(assigns[:user_search].items).to eq [ {
      'id' => admin.id,
      'account_id' => admin.account.id,
      'entity_user_id' => admin.entity_user_id,
      'full_name' => 'Administrator',
      'name' => admin.name,
      'username' => 'admin'
    } ]

    get :index, search_term: 'st'
    expect(assigns[:user_search].items.length).to eq 2
    expect(assigns[:user_search].items.sort_by { |a| a[:id] }).to eq [ {
      'id' => admin.id,
      'account_id' => admin.account.id,
      'entity_user_id' => admin.entity_user_id,
      'full_name' => 'Administrator',
      'name' => admin.name,
      'username' => 'admin'
    }, {
      'id' => profile.id,
      'account_id' => profile.account.id,
      'entity_user_id' => profile.entity_user_id,
      'full_name' => 'User One',
      'name' => profile.name,
      'username' => 'student'
    } ]
  end

  it 'creates a new user' do
    post :create, user: {
      username: 'new',
      password: 'password',
      first_name: 'New',
      last_name: 'User',
      full_name: 'Overriden!'
    }

    get :index, search_term: 'new'
    expect(assigns[:user_search].items.length).to eq 1
    expect(assigns[:user_search].items.first).to include(
      username: 'new',
      name: 'New User',
      full_name: 'Overriden!')
  end

  it 'updates a user' do
    put :update, id: profile.id, user: {
      username: 'updated',
      full_name: 'Updated Name'
    }

    expect(profile.reload.username).to eq 'updated'
    expect(profile.full_name).to eq 'Updated Name'
  end
end
