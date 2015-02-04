FactoryGirl.define do
  factory :interactive_step do
    task_step nil

    after(:build) do |is|
      is.task_step ||= FactoryGirl.build(:task_step, step: is)
    end
  end
end
