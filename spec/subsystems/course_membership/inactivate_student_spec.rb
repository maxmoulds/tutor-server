require 'rails_helper'

RSpec.describe CourseMembership::InactivateStudent, type: :routine do
  let(:student)  { FactoryBot.create(:course_membership_student) }
  let!(:course)  { student.course }

  context "active student" do
    it "inactivates but does not delete the given student" do
      allow(student).to receive(:is_refund_allowed) { true }
      expect(RefundPayment).to receive(:perform_later).with(uuid: student.uuid)

      result = nil
      expect do
        result = described_class.call(student: student)
      end.to change{ student.reload.dropped? }.from(false).to(true)
      expect(result.errors).to be_empty

      expect(student.reload.course).to eq course
    end

    it "does not refund student after refund period elapses" do
      allow(student).to receive(:is_refund_allowed) { false }
      expect(RefundPayment).not_to receive(:perform_later).with(uuid: student.uuid)
      described_class.call(student: student)
    end
  end

  context "inactive student" do
    before { student.destroy }

    it "returns an error" do
      result = nil
      expect do
        result = described_class.call(student: student)
      end.not_to change { student.reload.dropped? }.from(true)
      expect(result.errors.first.code).to eq :already_inactive
    end
  end

end
