module Sprint007A
  class Main

    lev_routine

    protected

    def exec
      teacher = FactoryGirl.create :user, username: 'teacher'
      student = FactoryGirl.create :user, username: 'student'

      book = Domain::FetchAndImportBook.call(
               id: '7db9aa72-f815-4c3b-9cb6-d50cf5318b58'
             ).outputs.book
      course = Domain::CreateCourse.call.outputs.course
      Domain::AddBookToCourse.call(book: book, course: course)
      Domain::AddUserAsCourseTeacher.call(course: course, user: teacher)

      a = FactoryGirl.create :tasks_assistant, code_class_name: "IReadingAssistant"
      tp = FactoryGirl.create :tasks_task_plan, assistant: a,
                                          settings: { page_ids: [1, 2] }
      tp.tasking_plans << FactoryGirl.create(:tasks_tasking_plan, target: student,
                                                            task_plan: tp)
      DistributeTasks.call(tp)
    end

  end
end
