require 'rails_helper'

RSpec.describe CourseProfile::Models::Profile, type: :model do
  subject { FactoryGirl.create :course_profile_profile }

  it { is_expected.to belong_to(:course) }

  it { is_expected.to validate_presence_of(:course) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:timezone) }

  it { is_expected.to validate_uniqueness_of(:course) }

  it { is_expected.to validate_inclusion_of(:timezone)
                        .in_array(ActiveSupport::TimeZone.all.map(&:name)) }

  it 'validates format of default times' do
    subject.default_open_time = '16:32'
    expect(subject).to be_valid

    subject.default_due_time = '16:'
    expect(subject).not_to be_valid

    subject.default_open_time = '24:00'
    expect(subject).not_to be_valid

    subject.default_due_time = '23:60'
    expect(subject).not_to be_valid
  end
end
