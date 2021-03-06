require 'rails_helper'

RSpec.describe GetTaskCorePageIds, type: :routine do
  before(:all) do
    homework_assistant = FactoryBot.create(
      :tasks_assistant, code_class_name: 'Tasks::Assistants::HomeworkAssistant'
    )

    period = FactoryBot.create :course_membership_period
    course = period.course

    user = FactoryBot.create :user

    @role = AddUserAsPeriodStudent[user: user, period: period]

    reading_plan_1 = FactoryBot.create(:tasked_task_plan, owner: course, number_of_students: 0)
    @page_ids_1 = reading_plan_1.settings['page_ids'].map(&:to_i)
    pages_1 = Content::Models::Page.where(id: @page_ids_1).to_a
    homework_exercises_1 = pages_1.flat_map(&:exercises).sort_by(&:uid).first(5)
    homework_plan_1 = FactoryBot.create(
      :tasked_task_plan, owner: course,
                         type: 'homework',
                         assistant: homework_assistant,
                         ecosystem: pages_1.first.ecosystem,
                         number_of_students: 0,
                         settings: { 'exercise_ids' => homework_exercises_1.map{ |ex| ex.id.to_s },
                                     'exercises_count_dynamic' => 2 }
    )

    reading_plan_2 = FactoryBot.create(:tasked_task_plan, owner: course, number_of_students: 0)
    @page_ids_2 = reading_plan_2.settings['page_ids'].map(&:to_i)
    pages_2 = Content::Models::Page.where(id: @page_ids_2).to_a
    homework_exercises_2 = pages_2.flat_map(&:exercises).sort_by(&:uid).first(4)
    homework_plan_2 = FactoryBot.create(
      :tasked_task_plan, owner: course,
                         type: 'homework',
                         assistant: homework_assistant,
                         ecosystem: pages_2.first.ecosystem,
                         number_of_students: 0,
                         settings: { 'exercise_ids' => homework_exercises_2.map{ |ex| ex.id.to_s },
                                     'exercises_count_dynamic' => 3 }
    )

    reading_plan_3 = FactoryBot.create(:tasked_task_plan, owner: course, number_of_students: 0)
    @page_ids_3 = reading_plan_3.settings['page_ids'].map(&:to_i)
    pages_3 = Content::Models::Page.where(id: @page_ids_3).to_a
    homework_exercises_3 = pages_3.flat_map(&:exercises).sort_by(&:uid).first(3)
    homework_plan_3 = FactoryBot.create(
      :tasked_task_plan, owner: course,
                         type: 'homework',
                         assistant: homework_assistant,
                         ecosystem: pages_3.first.ecosystem,
                         number_of_students: 0,
                         settings: { 'exercise_ids' => homework_exercises_3.map{ |ex| ex.id.to_s },
                                     'exercises_count_dynamic' => 4 }
    )

    @reading_task_1 = reading_plan_1.tasks.joins(:taskings)
                                          .find_by(taskings: {entity_role_id: @role.id})
    @reading_task_2 = reading_plan_2.tasks.joins(:taskings)
                                          .find_by(taskings: {entity_role_id: @role.id})
    @reading_task_3 = reading_plan_3.tasks.joins(:taskings)
                                          .find_by(taskings: {entity_role_id: @role.id})
    @homework_task_1 = homework_plan_1.tasks.joins(:taskings)
                                            .find_by(taskings: {entity_role_id: @role.id})
    @homework_task_2 = homework_plan_2.tasks.joins(:taskings)
                                            .find_by(taskings: {entity_role_id: @role.id})
    @homework_task_3 = homework_plan_3.tasks.joins(:taskings)
                                            .find_by(taskings: {entity_role_id: @role.id})
  end

  let(:reading_tasks)  { [@reading_task_1,   @reading_task_2,    @reading_task_3] }
  let(:homework_tasks) { [@homework_task_1,  @homework_task_2,  @homework_task_3] }

  let(:expected_core_page_ids) { [@page_ids_1, @page_ids_2, @page_ids_3] }

  it 'returns the correct core_page_ids for all tasks' do
    task_id_to_core_page_ids_map = described_class[tasks: reading_tasks + homework_tasks]

    reading_tasks.each_with_index do |task, index|
      expect(task_id_to_core_page_ids_map[task.id]).to eq expected_core_page_ids[index]
    end

    homework_tasks.each_with_index do |task, index|
      expect(task_id_to_core_page_ids_map[task.id]).to eq expected_core_page_ids[index]
    end
  end
end
