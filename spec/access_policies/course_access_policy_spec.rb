require 'rails_helper'

RSpec.describe CourseAccessPolicy, type: :access_policy do

  before(:all) do
    @course = FactoryBot.create :course_profile_course
    @period = FactoryBot.create :course_membership_period, course: @course

    @clone_course = FactoryBot.create :course_profile_course, cloned_from: @course
    @clone_period = FactoryBot.create :course_membership_period, course: @clone_course

    @anonymous = User::User.anonymous
    @user = FactoryBot.create(:user)
    @student = FactoryBot.create(:user)
    @teacher = FactoryBot.create(:user)
    @faculty = FactoryBot.create(:user)
    @new_faculty = FactoryBot.create(:user)
    @clone_student = FactoryBot.create(:user)
    @clone_teacher = FactoryBot.create(:user)
    @clone_faculty = FactoryBot.create(:user)

    AddUserAsPeriodStudent[period: @period, user: @student]
    AddUserAsCourseTeacher[course: @course, user: @teacher]
    AddUserAsCourseTeacher[course: @course, user: @faculty]
    AddUserAsPeriodStudent[period: @clone_period, user: @clone_student]
    AddUserAsCourseTeacher[course: @clone_course, user: @clone_teacher]
    AddUserAsCourseTeacher[course: @clone_course, user: @clone_faculty]

    @faculty.account.update_attribute :faculty_status, :confirmed_faculty
    @new_faculty.account.update_attribute :faculty_status, :confirmed_faculty
    @clone_faculty.account.update_attribute :faculty_status, :confirmed_faculty
  end

  context 'original course' do
    # action, requestor are set in contexts
    subject(:allowed) { described_class.action_allowed?(action, requestor, @course) }

    context 'anonymous user' do
      let(:requestor) { @anonymous }

      [:index, :read, :read_task_plans, :export, :roster, :add_period,
       :update, :stats, :exercises, :clone, :create].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq false }
        end
      end
    end

    context 'regular user' do
      let(:requestor) { @user }

      context ":index" do
        let(:action) { :index }
        it { should eq true }
      end

      [:read, :read_task_plans, :export, :roster, :add_period,
       :update, :stats, :exercises, :clone, :create].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq false }
        end
      end
    end

    context 'student in original course' do
      let(:requestor) { @student }

      [:index, :read].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq true }
        end
      end

      [:read_task_plans, :export, :roster, :add_period, :update,
       :stats, :exercises, :clone, :create].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq false }
        end
      end
    end

    context 'student in cloned course' do
      let(:requestor) { @clone_student }

      context 'index' do
        let(:action) { :index }
        it { should eq true }
      end

      [:create, :read, :read_task_plans, :export, :roster,
       :add_period, :update, :stats, :exercises, :clone].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq false }
        end
      end
    end

    context 'unverified faculty in original course' do
      let(:requestor) { @teacher }

      context 'create' do
        let(:action) { :create }
        it { should eq false }
      end

      [:index, :read, :read_task_plans, :export, :roster, :add_period,
       :update, :stats, :exercises, :clone].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq true }
        end
      end
    end

    context 'unverified faculty in cloned course' do
      let(:requestor) { @clone_teacher }

      [:index, :read_task_plans].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq true }
        end
      end

      [:create, :read, :export, :roster, :add_period,
       :update, :stats, :exercises, :clone].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq false }
        end
      end
    end

    context 'verified faculty in original course' do
      let(:requestor) { @faculty }

      [:index, :create, :read, :read_task_plans, :export, :roster,
       :add_period, :update, :stats, :exercises, :clone].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq true }
        end
      end
    end

    context 'verified faculty in cloned course' do
      let(:requestor) { @clone_faculty }

      [:index, :create, :read_task_plans].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq true }
        end
      end

      [:read, :export, :roster, :add_period, :update,
       :stats, :exercises, :clone].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq false }
        end
      end
    end

    context 'verified faculty without a course' do
      let(:requestor) { @new_faculty }

      [:index, :create].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq true }
        end
      end

      [:read, :read_task_plans, :export, :roster, :add_period,
      :update, :stats, :exercises, :clone].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq false }
        end
      end
    end
  end

  context 'cloned course' do
    # action, requestor are set in contexts
    subject(:allowed) { described_class.action_allowed?(action, requestor, @clone_course) }

    context 'anonymous user' do
      let(:requestor) { @anonymous }

      [:index, :read, :read_task_plans, :export, :roster, :add_period,
       :update, :stats, :exercises, :clone, :create].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq false }
        end
      end
    end

    context 'regular user' do
      let(:requestor) { @user }

      context ":index" do
        let(:action) { :index }
        it { should eq true }
      end

      [:read, :read_task_plans, :export, :roster, :add_period,
       :update, :stats, :exercises, :clone, :create].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq false }
        end
      end
    end

    context 'student in original course' do
      let(:requestor) { @student }

      context 'index' do
        let(:action) { :index }
        it { should eq true }
      end

      [:create, :read, :read_task_plans, :export, :roster,
       :add_period, :update, :stats, :exercises, :clone].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq false }
        end
      end
    end

    context 'student in cloned course' do
      let(:requestor) { @clone_student }

      [:index, :read].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq true }
        end
      end

      [:read_task_plans, :export, :roster, :add_period, :update,
       :stats, :exercises, :clone, :create].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq false }
        end
      end
    end

    context 'unverified faculty in original course' do
      let(:requestor) { @teacher }

      context 'index' do
        let(:action) { :index }
        it { should eq true }
      end

      [:create, :read, :read_task_plans, :export, :roster,
       :add_period, :update, :stats, :exercises, :clone].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq false }
        end
      end
    end

    context 'unverified faculty in cloned course' do
      let(:requestor) { @clone_teacher }

      context 'create' do
        let(:action) { :create }
        it { should eq false }
      end

      [:index, :read, :read_task_plans, :export, :roster,
       :add_period, :update, :stats, :exercises, :clone].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq true }
        end
      end
    end

    context 'verified faculty in original course' do
      let(:requestor) { @faculty }

      [:index, :create].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq true }
        end
      end

      [:read, :read_task_plans, :export, :roster, :add_period,
       :update, :stats, :exercises, :clone].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq false }
        end
      end
    end

    context 'verified faculty in cloned course' do
      let(:requestor) { @clone_faculty }

      [:index, :create, :read, :read_task_plans, :export, :roster,
       :add_period, :update, :stats, :exercises, :clone].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq true }
        end
      end
    end

    context 'verified faculty without a course' do
      let(:requestor) { @new_faculty }

      [:index, :create].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq true }
        end
      end

      [:read, :read_task_plans, :export, :roster, :add_period,
       :update, :stats, :exercises, :clone].each do |test_action|
        context "#{test_action}" do
          let(:action) { test_action }
          it { should eq false }
        end
      end
    end
  end

end
