require 'rails_helper'

RSpec.describe Tasks::Models::Task, :type => :model do
  it { is_expected.to belong_to(:task_plan) }

  it { is_expected.to have_many(:task_steps).dependent(:destroy) }
  it { is_expected.to have_many(:taskings).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:opens_at) }

  it "requires non-nil due_at to be after opens_at" do
    task = FactoryGirl.build(:tasks_task, due_at: nil)
    expect(task).to be_valid

    task = FactoryGirl.build(:tasks_task, due_at: Time.now - 1.week)
    expect(task).to_not be_valid
  end

  it "reports is_shared correctly" do
    at1 = FactoryGirl.create(:tasks_tasking)
    at1.reload
    expect(at1.task.is_shared).to be_falsy

    at2 = FactoryGirl.create(:tasks_tasking, task: at1.task)
    at1.reload
    expect(at1.task.is_shared).to be_truthy
  end

  it 'reports tasked_to? for a taskee' do
    user = FactoryGirl.create(:user)
    tasking = FactoryGirl.build(:tasks_tasking, taskee: user)
    task = FactoryGirl.create(:tasks_task, taskings: [tasking])

    expect(task).to be_tasked_to(user)

    task.taskings.clear
    expect(task).not_to be_tasked_to(user)
  end
end
