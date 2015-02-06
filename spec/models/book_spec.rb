require 'rails_helper'

RSpec.describe Book, :type => :model do
  subject { FactoryGirl.create :book }

  it { is_expected.to have_many(:chapters).dependent(:destroy) }

  it { is_expected.to belong_to(:resource) }

  it { is_expected.to validate_presence_of(:resource) }

  it { is_expected.to validate_uniqueness_of(:resource) }
end
