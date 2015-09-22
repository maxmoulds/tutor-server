class EcosystemAccessPolicy
  def self.action_allowed?(action, requestor, ecosystem)
    return false unless requestor.is_human?

    case action
    when :readings
      # readings should be readable by course teachers and students
      # because FE uses it for the reference view
      courses = GetUserCourses[user: requestor.entity_user]
      courses.any?{ |course| course.ecosystems.collect(&:id).include?(ecosystem.id) }
    when :exercises
      # exercises should be readable by course teachers only
      # because it includes solutions, etc
      courses = GetUserCourses[user: requestor.entity_user, types: :teacher]
      courses.any?{ |course| course.ecosystems.collect(&:id).include?(ecosystem.id) }
    else
      false
    end
  end
end