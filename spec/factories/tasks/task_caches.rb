FactoryBot.define do
  factory :tasks_task_cache, class: 'Tasks::Models::TaskCache' do
    association   :task,      factory: :tasks_task
    association   :ecosystem, factory: :content_ecosystem
    task_type     { task.task_type }
    student_ids   { task.taskings.map { |tasking| tasking.role.student.id } }
    student_names { task.taskings.map { |tasking| tasking.role.student.name } }
    as_toc        { { books: [] } }
  end
end
