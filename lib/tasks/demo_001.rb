class Demo001

  lev_routine

  uses_routine FetchAndImportBook, as: :import_book, translations: { outputs: { type: :verbatim } }
  uses_routine CreateCourse, as: :create_course
  uses_routine AddBookToCourse, as: :add_book
  uses_routine UserProfile::CreateProfile, as: :create_profile
  uses_routine AddUserAsCourseTeacher, as: :add_teacher
  uses_routine AddUserAsCourseStudent, as: :add_student
  uses_routine DistributeTasks, as: :distribute
  uses_routine Content::GetLos, as: :get_los
  uses_routine SearchLocalExercises, as: :search_exercises
  uses_routine MarkTaskStepCompleted, as: :mark_completed
  uses_routine TaskExercise, as: :task_exercise

  protected

  DEFAULT_TASK_DURATION = 1.week


  def exec(random_seed: nil)

    # By default, choose a fixed seed for repeatability and fewer surprises
    @random_seed = random_seed

    exercises_url = 'https://exercises-demo.openstax.org'
    archive_url = 'https://archive-staging-tutor.cnx.org/contents/'

    OpenStax::Exercises::V1.with_configuration(server_url: exercises_url) do
      OpenStax::Cnx::V1.with_archive_url(url: archive_url) do
        run(:import_book, id: 'e4c329f3-1972-4835-a203-3e8c539e4df3@2.14')
      end
    end

    course = create_course(name: 'Physics I')
    run(:add_book, book: outputs.book, course: course)

    teacher_profile = new_user_profile(username: 'teacher', name: 'Bill Nye')
    run(:add_teacher, course: course, user: teacher_profile.entity_user)

    students = 1.times.collect do |ii|
      new_course_student(course: course, username: "student#{(ii + 1).to_s.rjust(2,'0')}")
    end

    initial_date = Chronic.parse("October 14, 2015")


    ### First Chapter 3 iReading
    #
    # Steps:        r  r  e  r  r  r  e  v  e  r  r  i  e  r  r  e  r  r  r  e  r  e  r
    #
    responses = [
                  [ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 ],
                ]

    assign_ireading(course: course,
                    chapter_sections: ['3.1', '3.2', '3.3'],
                    due_at: initial_date - 5.days).each_with_index do |ireading, index|

      work_task(task: ireading, responses: responses[index])

    end

    ### First Chapter 3 HW
    #
    # Steps:        e  e  e  e  e  e  e  e  e  e
    #

    responses = [
                  [ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 ],
                ]

    assign_homework(course: course,
                    chapter_sections: ['3.1', '3.2', '3.3'],
                    num_exercises: 10,
                    due_at: initial_date - 3.days).each_with_index do |hw, index|

      work_task(task: hw, responses: responses[index])

    end

    ### First Chapter 4 iReading
    # Steps:        r  i  e  r  r  e  r  r  r  e  r  e  r  e

    responses = [
                  [ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 ],
                ]

    assign_ireading(course: course,
                    chapter_sections: ['4.1', '4.2'],
                    due_at: initial_date - 2.days).each_with_index do |ireading, index|

      work_task(task: ireading, responses: responses[index])

    end

    ### First Chapter 4 HW
    #
    # Steps:        e  e  e  e  e  e  e  e
    #

    responses = [
                  [ 1, 1, 1, 1, 1, 1, 1, 1 ],
                ]

    assign_homework(course: course,
                    chapter_sections: ['4.1', '4.2'],
                    num_exercises: 8,
                    due_at: initial_date - 3.days).each_with_index do |hw, index|

      work_task(task: hw, responses: responses[index])

    end

# debugger
# debugger

  end

  #############################################################################
  #
  # HELPERS
  #
  #############################################################################




  def new_user_profile(username:, name: nil, password: 'password', sign_contracts: true)
    name ||= Faker::Name.name
    first_name, last_name = name.split(' ')
    raise "need a full name" if last_name.nil?

    # The password will be set if stubbing is disabled
    profile = run(:create_profile, username: username,
                                   password: password).outputs.profile

    # We call update_columns here so this update is not sent to OpenStax Accounts
    profile.account.update_columns(first_name: first_name, last_name: last_name, full_name: name)

    if sign_contracts
      sign_contract(profile: profile, name: :general_terms_of_use)
      sign_contract(profile: profile, name: :privacy_policy)
    end

    profile
  end

  def sign_contract(profile:, name:)
    string_name = name.to_s
    return if !FinePrint::Contract.any?{name == string_name}
    FinePrint.sign_contract(profile, string_name)
  end

  def new_course_student(course:, username: nil, name: nil, password: nil)
    profile = new_user_profile(username: username, name: name, password: password)
    user = profile.entity_user
    role = run(:add_student, course: course, user: user).outputs.role

    {
      profile: profile,
      user: user,
      role: role,
    }
  end

  # def make_and_work_practice_widget(role:, num_correct:, book_part_ids: [],
  #                                                        page_ids: [])
  #   # entity_task = ResetPracticeWidget[book_part_ids: book_part_ids,
  #   #                                   page_ids: page_ids,
  #   #                                   role: role, condition: :local]

  #   # entity_task.task.task_steps.first(num_correct).each do |task_step|
  #   #   Hacks::AnswerExercise[task_step: task_step, is_correct: true]
  #   # end
  # end

  def hw_assistant
    @hw_assistant ||= Tasks::Models::Assistant.create!(
      name: "Homework Assistant",
      code_class_name: "Tasks::Assistants::HomeworkAssistant"
    )
  end

  def reading_assistant
    @reading_assistant ||= Tasks::Models::Assistant.create!(
      name: "iReading Assistant",
      code_class_name: "Tasks::Assistants::IReadingAssistant"
    )
  end

  def assign_ireading(course:, chapter_sections:, due_at:, opens_at:nil, duration: nil, to: nil, title: nil)
    raise "Cannot set both opens_at and duration" if opens_at.present? && duration.present?
    duration ||= DEFAULT_TASK_DURATION
    opens_at ||= due_at - duration

    book = CourseContent::GetCourseBooks[course: course].first
    pages = lookup_pages(book: book, chapter_sections: chapter_sections)

    raise "No pages to assign" if pages.blank?

    task_plan = Tasks::Models::TaskPlan.create!(
      title: title || pages.first.title,
      owner: course,
      type: 'reading',
      assistant: reading_assistant,
      opens_at: opens_at,
      due_at: due_at,
      settings: { page_ids: pages.collect{|page| page.id.to_s} }
    )

    distribute_tasks(task_plan: task_plan,
                     to: to || course,
                     message: "Assigned ireading for #{chapter_sections}, due: #{due_at}, title: #{task_plan.title}")
  end

  def assign_homework(course:, chapter_sections:, due_at:, opens_at: nil, duration: nil,
                      num_exercises: 5, to: nil, title: nil)

    raise "Cannot set both opens_at and duration" if opens_at.present? && duration.present?
    duration ||= DEFAULT_TASK_DURATION
    opens_at ||= due_at - duration

    book = CourseContent::GetCourseBooks[course: course].first
    pages = lookup_pages(book: book, chapter_sections: chapter_sections)

    page_los = pages.collect(&:los).uniq

    exercise_ids = run(:search_exercises, tag: page_los, match_count: 1)
                       .outputs.items
                       .shuffle(random: randomizer)
                       .take(num_exercises)
                       .collect{ |e| e.id.to_s }

    task_plan = Tasks::Models::TaskPlan.create!(
      title: title || "Homework - #{chapter_sections.join('-')}",
      owner: course,
      type: 'homework',
      assistant: hw_assistant,
      opens_at: opens_at,
      due_at: due_at,
      settings: {
        page_ids: pages.collect{|page| page.id.to_s},
        exercise_ids: exercise_ids,
        exercises_count_dynamic: rand(3)+2
      }
    )

    distribute_tasks(task_plan: task_plan, to: to || course)
  end

  def distribute_tasks(task_plan:, to:, message: nil)
    log(message || "Assigned #{task_plan.type}, '#{task_plan.title}' due at #{task_plan.due_at}")

    task_plan.tasking_plans << Tasks::Models::TaskingPlan.create!(target: to, task_plan: task_plan)
    tasks = run(:distribute, task_plan).outputs.tasks

    log("First task: " + print_task(task: tasks.first)) if tasks.any?

    tasks
  end

  # `responses` is an array of 1 (or true), 0 (or false), or nil; nil means
  # not completed; any non-nil means completed. 1/0 (true/false) is for
  # exercise correctness
  def work_task(task:, responses:)

    core_task_steps = task.task_steps.core_group
    core_task_steps_count = core_task_steps.count

    raise "Not enough core responses" if responses.count < core_task_steps_count

    core_task_steps.each_with_index do |step, index|
      work_step(step, responses[index])
    end

    return if !task.core_task_steps_completed?

    noncore_steps = task.task_steps(true).incomplete

    raise "Not enough noncore responses" \
      if responses.count < noncore_steps.count + core_task_steps_count

    noncore_steps.each_with_index do |step, index|
      work_step(step, responses[index + core_task_steps_count])
    end
  end

  # Works a step with the given response; for exercise steps, response can be
  # true/false or 1/0 to represent right or wrong.  For any step, a nil means
  # incomplete, non-nil means complete.
  def work_step(step, response)
    return if response.nil?
    response = (response.zero? ? false : true) if response.is_a?(Integer)

    if step.tasked.exercise?
      Hacks::AnswerExercise.call(task_step: step, is_correct: response)
    else
      run(:mark_completed, task_step: step)
    end
  end

  def lookup_pages(book:, chapter_sections:)
    chapter_sections = [chapter_sections].flatten.compact

    @page_data ||= {}
    @page_data[book.id] ||= Content::VisitBook[book: book, visitor_names: :page_data]

    @page_data[book.id].select{|pd| chapter_sections.include?(pd.chapter_section)}
  end


  def create_course(name:)
    course = run(:create_course, name: name).outputs.course

    # Add assistants to course so teacher can create assignments
    Tasks::Models::CourseAssistant.create!(course: course,
                                           assistant: reading_assistant,
                                           tasks_task_plan_type: 'reading')
    Tasks::Models::CourseAssistant.create!(course: course,
                                           assistant: hw_assistant,
                                           tasks_task_plan_type: 'homework')

    course
  end

  def log(message)
    puts "#{message}\n"
  end

  def print_task(task:)
    types = task.task_steps.collect do |step|
      code = case step.tasked
      when Tasks::Models::TaskedExercise
        "e"
      when Tasks::Models::TaskedReading
        'r'
      when Tasks::Models::TaskedVideo
        'v'
      when Tasks::Models::TaskedInteractive
        'i'
      else
        'o'
      end

      "#{step.id}#{code}"
    end

    "Task #{task.id} / #{task.task_type} / #{types.join(' ')}"
  end

  def randomizer
    @randomizer ||= Random.new(@random_seed || 1234)
  end

  def rand(max=nil)
    max.nil? ? randomizer.rand : randomizer.rand(max)
  end

end
