require 'rails_helper'

RSpec.feature 'Admnistration' do
  scenario 'visit the admin dashboard' do
    admin = FactoryBot.create(:user, :administrator)
    stub_current_user(admin)

    visit admin_root_path

    expect(page).to have_content('Tutor Admin Console')
    expect(page).to have_link('Courses', href: admin_courses_path)
  end

  context 'pages are reachable via the menu' do
    scenario 'System Setting/Settings' do
      admin = FactoryBot.create(:user, :administrator)
      stub_current_user(admin)
      visit admin_root_path

      click_link 'System Setting'
      click_link 'Settings'

      expect(page).to have_content('Global Settings')
      expect(page).to have_content('Excluded exercise IDs')
      fill_in 'settings_excluded_ids', with: '123456@7'

      expect(SendGlobalExerciseExclusionsToBiglearn).to receive(:perform_later).once
      click_button 'Save'
    end

    scenario 'Salesforce' do
      admin = FactoryBot.create(:user, :administrator)
      stub_current_user(admin)
      stub_current_user(admin, OpenStax::Salesforce::SettingsController)
      visit admin_root_path

      click_link 'Salesforce'
      click_link 'Setup'
      expect(page).to have_content "Salesforce Setup"
    end

    scenario 'Payments' do
      admin = FactoryBot.create(:user, :administrator)
      stub_current_user(admin)
      visit admin_root_path

      click_link 'Payments'
      expect(page).to have_content "Extend Payment"
    end
  end
end
