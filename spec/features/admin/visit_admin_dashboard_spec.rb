require 'rails_helper'

RSpec.feature 'Admnistration' do
  scenario 'visit the admin dashboard' do
    admin = FactoryGirl.create(:user, :administrator)
    stub_current_user(admin)

    visit admin_root_path

    expect(page).to have_content('Tutor Admin Console')
    expect(page).to have_link('Courses', href: admin_courses_path)
  end

  context 'pages are reachable via the menu' do
    scenario 'System Setting/Settings' do
      admin = FactoryGirl.create(:user, :administrator)
      stub_current_user(admin)
      visit admin_root_path

      click_link 'System Setting'
      click_link 'Settings'

      expect(page).to have_content('Global Settings')
      expect(page).to have_content('Excluded exercise IDs')
      fill_in 'settings_excluded_ids', with: '123456@7'

      2.times { FactoryGirl.create :course_profile_course }
      num_courses = CourseProfile::Models::Course.count
      expect(OpenStax::Biglearn::Api).to(
        receive(:update_globally_excluded_exercises).exactly(num_courses).times
      )
      click_button 'Save'
    end

    scenario 'Salesforce' do
      admin = FactoryGirl.create(:user, :administrator)
      stub_current_user(admin)
      stub_current_user(admin, OpenStax::Salesforce::SettingsController)
      visit admin_root_path

      click_link 'Salesforce'
      click_link 'Setup'
      expect(page).to have_content "Salesforce Setup"
    end

    scenario 'Payments' do
      admin = FactoryGirl.create(:user, :administrator)
      stub_current_user(admin)
      visit admin_root_path

      click_link 'Payments'
      expect(page).to have_content "Extend Payment"
    end
  end
end
