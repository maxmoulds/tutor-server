require "rails_helper"

RSpec.describe Api::V1::TaskStepsController, type: :controller, api: true,
                                             version: :v1, speed: :slow do

  let(:course)           { FactoryBot.create :course_profile_course }
  let(:period)           { FactoryBot.create :course_membership_period, course: course }

  let(:application)      { FactoryBot.create :doorkeeper_application }
  let(:user_1)           { FactoryBot.create :user }
  let(:user_1_token)     do
    FactoryBot.create :doorkeeper_access_token, application: application,
                                                resource_owner_id: user_1.id
  end
  let(:user_1_role)      { AddUserAsPeriodStudent[user: user_1, period: period] }

  let(:user_2)           { FactoryBot.create(:user) }
  let(:user_2_token)     do
    FactoryBot.create :doorkeeper_access_token, application: application,
                                                resource_owner_id: user_2.id
  end

  let(:userless_token)   { FactoryBot.create :doorkeeper_access_token, application: application }

  let(:task_step)        do
    FactoryBot.create :tasks_task_step, title: 'title', url: 'http://u.rl', content: 'content'
  end

  let(:task) { task_step.task.reload }

  let!(:tasking) { FactoryBot.create :tasks_tasking, role: user_1_role, task: task }

  let!(:tasked_exercise) do
    te = FactoryBot.build :tasks_tasked_exercise
    te.task_step.task = task
    te.save!
    te
  end

  let(:lo) { FactoryBot.create :content_tag, value: 'ost-tag-lo-test-lo01' }
  let(:pp) { FactoryBot.create :content_tag, value: 'os-practice-problems' }

  let(:related_exercise) { FactoryBot.create :content_exercise, tags: [lo.value, pp.value] }

  let!(:tasked_exercise_with_related) do
    content = OpenStax::Exercises::V1::FakeClient.new_exercise_hash(tags: [lo.value]).to_json
    ce = FactoryBot.build :content_exercise, content: content
    FactoryBot.build(:tasks_tasked_exercise, exercise: ce).tap do |te|
      te.task_step.task = task
      te.task_step.related_exercise_ids = [related_exercise.id]
      te.save!
    end
  end

  let(:teacher_user)       { FactoryBot.create(:user) }
  let!(:teacher_role)      { AddUserAsCourseTeacher[course: course, user: teacher_user] }
  let(:teacher_user_token) do
    FactoryBot.create :doorkeeper_access_token, application: application,
                                                resource_owner_id: teacher_user.id
  end

  context "#show" do
    it "should work on the happy path" do
      api_get :show, user_1_token, parameters: { task_id: task_step.task.id, id: task_step.id }
      expect(response).to have_http_status(:success)

      expect(response.body_as_hash).to include({
        id: task_step.id.to_s,
        task_id: task_step.tasks_task_id.to_s,
        type: 'reading',
        title: 'title',
        chapter_section: task_step.tasked.book_location,
        is_completed: false,
        content_url: 'http://u.rl',
        content_html: 'content',
        related_content: a_kind_of(Array)
      })
    end

    context 'student' do
      it "422's if needs to pay" do
        make_payment_required_and_expect_422(course: course, user: user_1) do
          api_get :show, user_1_token, parameters: { task_id: task_step.task.id, id: task_step.id }
        end
      end
    end

    context 'teacher' do
      it 'does not 422 if needs to pay' do
        make_payment_required_and_expect_not_422(course: course, user: user_1) do
          api_get :show, teacher_user_token,
                  parameters: { task_id: task_step.task.id, id: task_step.id }
        end
      end
    end

    it 'raises SecurityTransgression when user is anonymous or not a teacher' do
      expect do
        api_get :show, nil, parameters: { task_id: task_step.task.id, id: task_step.id }
      end.to raise_error(SecurityTransgression)

      expect do
        api_get :show, user_2_token, parameters: { task_id: task_step.task.id, id: task_step.id }
      end.to raise_error(SecurityTransgression)
    end
  end

  context "PATCH update" do

    let(:tasked)        { create_tasked(:tasked_exercise, user_1_role) }
    let(:id_parameters) { { task_id: tasked.task_step.task.id, id: tasked.task_step.id } }

    it "updates the free response of an exercise" do
      api_put :update, user_1_token, parameters: id_parameters,
              raw_post_data: { free_response: "Ipsum lorem" }

      expect(response).to have_http_status(:success)

      expect(response.body).to eq(
        Api::V1::Tasks::TaskedExerciseRepresenter.new(tasked.reload).to_json
      )

      expect(tasked.reload.free_response).to eq "Ipsum lorem"
    end

    it "422's if needs to pay" do
      make_payment_required_and_expect_422(course: course, user: user_1) {
        api_put :update, user_1_token, parameters: id_parameters,
                raw_post_data: { free_response: "Ipsum lorem" }
      }
    end

    it "updates the selected answer of an exercise" do
      tasked.free_response = "Ipsum lorem"
      tasked.save!
      answer_id = tasked.answer_ids.first

      api_put :update, user_1_token,
              parameters: id_parameters, raw_post_data: { answer_id: answer_id.to_s }

      expect(response).to have_http_status(:success)

      expect(response.body).to eq(
        Api::V1::Tasks::TaskedExerciseRepresenter.new(tasked.reload).to_json
      )

      expect(tasked.reload.answer_id).to eq answer_id
    end

    it "does not update the answer if the free response is not set" do
      answer_id = tasked.answer_ids.first

      api_put :update, user_1_token,
              parameters: id_parameters, raw_post_data: { answer_id: answer_id.to_s }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(tasked.reload.answer_id).to be_nil
    end

    it 'returns an error when the free response is blank' do
      api_put :update, user_1_token,
              parameters: id_parameters, raw_post_data: { free_response: ' ' }

      expect(response).to have_http_status(:unprocessable_entity)
    end

  end

  context "#recovery" do
    it "should allow owner to add related exercises after steps that have related_exercise_ids" do
      expect {
        api_put :recovery, user_1_token, parameters: {
          id: tasked_exercise_with_related.task_step.id
        }
      }.to change{tasked_exercise_with_related.task_step.task.reload.task_steps.count}
      expect(response).to have_http_status(:success)

      related_exercise_step = tasked_exercise_with_related.task_step.next_by_number
      tasked = related_exercise_step.tasked

      expect(response.body).to(
        eq Api::V1::Tasks::TaskedExerciseRepresenter.new(tasked).to_json
      )

      expect(tasked.los & tasked_exercise_with_related.parser.los).not_to be_empty
      expect(related_exercise_step.task).to eq(task)
      expect(related_exercise_step.number).to(
        eq(tasked_exercise_with_related.task_step.number + 1)
      )
    end

    it "should not allow random user to call it" do
      step_count = tasked_exercise_with_related.task_step.task.task_steps.count

      expect{
        api_put :recovery, user_2_token, parameters: {
          id: tasked_exercise_with_related.task_step.id
        }
      }.to raise_error SecurityTransgression

      expect(tasked_exercise.task_step.task.reload.task_steps.count).to(
        eq step_count
      )
    end

    it "should not allow owner to call it on steps that don't have related_exercise_ids" do
      expect{
        api_put :recovery, user_1_token, parameters: {
          id: tasked_exercise.task_step.id
        }
      }.not_to change{tasked_exercise.task_step.task.reload.task_steps.count}

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context "#completed" do
    it "should allow marking completion of reading steps by the owner" do
      tasked = create_tasked(:tasked_reading, user_1_role)
      api_put :completed, user_1_token, parameters: { id: tasked.task_step.id }

      expect(response).to have_http_status(:success)

      expect(response.body).to eq(Api::V1::TaskRepresenter.new(
        tasked.reload.task_step.task
      ).to_json)

      expect(tasked.task_step(true).completed?).to be_truthy
    end

    it "422's if needs to pay" do
      tasked = create_tasked(:tasked_reading, user_1_role)
      make_payment_required_and_expect_422(course: course, user: user_1) {
        api_put :completed, user_1_token, parameters: { id: tasked.task_step.id }
      }
    end

    it "should not allow marking completion of reading steps by random user" do
      tasked = create_tasked(:tasked_reading, user_1_role)
      expect{
        api_put :completed, user_2_token, parameters: { id: tasked.task_step.id }
      }.to raise_error SecurityTransgression
      expect(tasked.task_step(true).completed?).to be_falsy
    end

    it "should allow marking completion of exercise steps with free_response and answer_id" do
      tasked = create_tasked(:tasked_exercise, user_1_role)
      tasked.free_response = 'abc'
      tasked.answer_id = tasked.correct_answer_id
      tasked.save!
      api_put :completed, user_1_token, parameters: { id: tasked.task_step.id }

      expect(response).to have_http_status(:success)

      expect(response.body).to eq(
        Api::V1::TaskRepresenter.new(tasked.reload.task_step.task).to_json
      )

      expect(tasked.task_step(true).completed?).to be_truthy
    end

    it "should not allow marking completion of exercise steps missing free_response or answer_id" do
      tasked = create_tasked(:tasked_exercise, user_1_role).reload
      api_put :completed, user_1_token, parameters: { id: tasked.task_step.id }

      expect(response).to have_http_status(:unprocessable_entity)

      errors = response.body_as_hash[:errors]
      expect(errors.size).to eq 2
      errors.each { |error| expect(error[:code]).to include 'is required' }

      expect(tasked.task_step(true).completed?).to be_falsy
    end
  end

  context "practice task update step" do
    let(:step) do
      page = tasked_exercise.exercise.page

      Content::Routines::PopulateExercisePools[book: page.book]

      page.practice_widget_pool.update_attribute :content_exercise_ids,
                                                 [tasked_exercise.content_exercise_id]

      ecosystem = Content::Ecosystem.new strategy: page.ecosystem.wrap

      AddEcosystemToCourse[course: course, ecosystem: ecosystem]

      task = CreatePracticeSpecificTopicsTask[course: course, role: user_1_role, page_ids: [page.id]]

      task.task_steps.first
    end

    it "allows updating of a step" do

      api_put :update, user_1_token, parameters: { id: step.id },
              raw_post_data: { free_response: "Ipsum lorem" }
      expect(response).to have_http_status(:success)
    end

    it "422's if needs to pay" do
      make_payment_required_and_expect_422(course: course, user: user_1) {
        api_put :update, user_1_token, parameters: { id: step.id },
                raw_post_data: { free_response: "Ipsum lorem" }
      }
    end
  end

  # TODO: could replace with FactoryBot calls like in TaskedExercise factory examples
  def create_tasked(type, owner)
    # Make sure the type has the tasks_ prefix
    type = type.to_s.starts_with?("tasks_") ? type : "tasks_#{type}".to_sym
    tasked = FactoryBot.create(type)
    tasking = FactoryBot.create(:tasks_tasking, role: owner, task: tasked.task_step.task)
    tasked
  end

end
