require 'rails_helper'

RSpec.describe Settings::Payments, type: :lib do
  it 'can store student_grace_period_days' do
    expect(described_class.student_grace_period_days).to eq 14

    described_class.student_grace_period_days = 10
    Settings::Db.store.object('student_grace_period_days').expire_cache
    expect(described_class.student_grace_period_days).to eq 10
  end
end
