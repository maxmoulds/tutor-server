require 'rails_helper'

RSpec.describe Admin::StatsController, type: :controller do

  let!(:admin) { FactoryGirl.create(:user, :administrator) }

  context "GET #courses" do
    let!(:course)        { Entity::Course.create! }
    let!(:periods)       do
      3.times.map { FactoryGirl.create :course_membership_period, course: course }
    end

    let!(:teacher_user)  { FactoryGirl.create :user }
    let!(:teacher_role)  { AddUserAsCourseTeacher[course: course, user: teacher_user] }

    let!(:student_roles) do
      5.times.map do
        user = FactoryGirl.create :user
        AddUserAsPeriodStudent[period: periods.sample, user: user]
      end
    end

    it "returns http success" do
      controller.sign_in admin

      get :courses
      expect(response).to have_http_status(:success)
    end
  end

  context "GET #concept_coach" do
    let!(:tasks)         do
      3.times.map { FactoryGirl.create :tasks_task, task_type: :concept_coach }
    end
    let!(:cc_tasks)       do
      tasks.map do |task|
        FactoryGirl.create :tasks_concept_coach_task, task: task.entity_task
      end
    end

    it "returns http success" do
      controller.sign_in admin

      get :concept_coach
      expect(response).to have_http_status(:success)
    end
  end

end