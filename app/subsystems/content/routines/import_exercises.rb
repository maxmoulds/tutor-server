class Content::Routines::ImportExercises

  lev_routine

  uses_routine Content::Routines::FindOrCreateTags, as: :find_or_create_tags
  uses_routine Content::Routines::TagResource, as: :tag

  protected

  # TODO: make this routine import only exercises from trusted authors
  #       or in some trusted list (for when OS Exercises is public)
  # page can be a Content::Models::Page or a block
  # that takes an OpenStax::Exercises::V1::Exercise
  # and returns a Content::Models::Page for that exercise
  def exec(ecosystem:, page:, query_hash:, excluded_exercise_numbers: Set.new)
    outputs[:exercises] = []

    wrappers = OpenStax::Exercises::V1.exercises(query_hash)['items']
    wrapper_urls = wrappers.uniq(&:url)

    wrapper_tag_hashes = wrappers.flat_map(&:tag_hashes).uniq{ |hash| hash[:value] }
    tags = run(:find_or_create_tags, ecosystem: ecosystem, input: wrapper_tag_hashes).outputs.tags

    exercise_pages = wrappers.map do |wrapper|
      next if excluded_exercise_numbers.include? wrapper.number

      exercise_page = page.respond_to?(:call) ? page.call(wrapper) : page
      next if exercise_page.nil?

      exercise = Content::Models::Exercise.new(url: wrapper.url,
                                               number: wrapper.number,
                                               version: wrapper.version,
                                               title: wrapper.title,
                                               content: wrapper.content,
                                               page: exercise_page)
      transfer_errors_from(exercise, {type: :verbatim}, true)

      relevant_tags = tags.select{ |tag| wrapper.tags.include?(tag.value) }
      run(:tag, exercise, relevant_tags, tagging_class: Content::Models::ExerciseTag, save: false)

      outputs[:exercises] << exercise

      exercise_page
    end.compact.uniq

    Content::Models::Exercise.import! outputs[:exercises], recursive: true

    # Reset associations so they get reloaded the next time they are used
    page.exercises.reset if page.is_a?(Content::Models::Page)

    exercise_pages.each{ |page| page.exercises.reset }

    outputs[:exercises].each do |exercise|
      exercise.exercise_tags.reset
      exercise.tags.reset
    end
  end
end
