require 'rails_helper'
require 'vcr_helper'
require 'tasks/demo/content'
require 'tasks/demo/tasks'
require 'tasks/demo/work'

RSpec.describe 'Demo', type: :request, version: :v1, speed: :slow, vcr: VCR_OPTS do
  # Transactions are not compatible with multiple processes
  self.use_transactional_fixtures = false

  after(:all) { DatabaseCleaner.clean_with :truncation }

  context 'with the stable book version' do
    it "doesn't catch on fire" do
      # The demo rake task runs demo:content, demo:tasks and demo:work
      # For testing a lightweight import is performed so it completes faster
      # The customized import files for the are located in the fixtures directory
      fixtures_directory = File.join(File.dirname(__FILE__),'../../fixtures/demo-imports')
      ContentConfiguration.with_config_directory(fixtures_directory) do
        expect(DemoContent.call(print_logs: false).errors).to be_empty
        expect(DemoTasks.call(print_logs: false).errors).to be_empty
        expect(DemoWork.call(print_logs: false).errors).to be_empty
      end

      # We expect some users with no full_name for testing
      accounts = OpenStax::Accounts::Account.all.to_a
      expect(accounts.any?{ |acc| acc.full_name.blank? }).to eq true

      # We expect some tasks in each possible state
      tasks = Tasks::Models::Task.preload(:task_steps).to_a

      expect(tasks.any?{ |task| task.status == 'not_started' }).to eq true
      expect(tasks.any?{ |task| task.status == 'in_progress' }).to eq true
      expect(tasks.any?{ |task| task.status == 'completed' }).to eq true

      # The step status actually matches the task status
      tasks.reject(&:in_progress?).reject(&:completed?).each do |unstarted_task|
        expect(unstarted_task.task_steps.any?(&:completed?)).to eq false
      end

      tasks.select(&:in_progress?).each do |in_progress_task|
        expect(in_progress_task.task_steps.any?(&:completed?)).to eq true
        expect(in_progress_task.task_steps.all?(&:completed?)).to eq false
      end

      tasks.select(&:completed?).each do |completed_task|
        expect(completed_task.task_steps.all?(&:completed?)).to eq true
      end
    end
  end

end
