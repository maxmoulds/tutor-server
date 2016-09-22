require_relative 'base'

# Adds students to the course periods, assigns Sets up the periods and students for a course
# and then generates activity for them
class Demo::Tasks < Demo::Base

  lev_routine

  disable_automatic_lev_transactions

  uses_routine DistributeTasks

  protected

  def exec(config: :all, print_logs: true, random_seed: nil)
    set_print_logs(print_logs)
    set_random_seed(random_seed)

    parallel_each(Demo::ContentConfiguration[config], transaction: true) do | content, index |
      content.assignments.each do | assignment |
        create_assignment(content, assignment)
      end

      get_auto_assignments(content).flatten.each do | auto_assignment |
        create_assignment(content, auto_assignment)
      end
    end

    Timecop.return_all
  end

  def create_assignment(content, assignment)
    log("Creating #{assignment.type} #{assignment.title} for course #{content.course_name}")

    course = content.course

    return assign_concept_coach(course: course) if assignment.type == 'concept_coach'

    task_plan = if assignment.type == 'reading'
                  assign_ireading(course: course,
                                  book_locations: assignment.book_locations,
                                  title: assignment.title)
                else
                  assign_homework(course: course,
                                  book_locations: assignment.book_locations,
                                  title: assignment.title,
                                  num_exercises: assignment.num_exercises)
                end

    assignment.periods.each do | period |
      log("  Adding tasking plan for period #{period.id}")
      course_period = course.periods.where(name: content.get_period(period.id).name).first!
      add_tasking_plan(task_plan: task_plan,
                       to: course_period,
                       opens_at: period.opens_at,
                       due_at: period.due_at)

      ShortCode::Create[task_plan.to_global_id.to_s]
    end
    # Draft plans do not undergo distribution
    if assignment.draft
      log("  Is a draft, skipping distributing")
    else
      log("  Distributing tasks")
      distribute_tasks(task_plan: task_plan)
    end
  end


end
