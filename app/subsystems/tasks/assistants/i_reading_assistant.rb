class Tasks::Assistants::IReadingAssistant < Tasks::Assistants::FragmentAssistant

  def self.schema
    '{
      "type": "object",
      "required": [
        "page_ids"
      ],
      "properties": {
        "page_ids": {
          "type": "array",
          "items": {
            "type": "string"
          },
          "minItems": 1,
          "uniqueItems": true
        }
      },
      "additionalProperties": false
    }'
  end

  def initialize(task_plan:, individualized_tasking_plans:)
    super

    @pages = ecosystem.pages_by_ids(task_plan.settings['page_ids'])
  end

  def build_tasks
    # Don't add dynamic exercises if all the reading dynamic exercise pools are empty
    # This happens, for example, on intro pages
    reading_dynamic_pools = ecosystem.reading_dynamic_pools(pages: @pages)
    skip_dynamic = reading_dynamic_pools.all?(&:empty?)

    roles = individualized_tasking_plans.map(&:target)
    histories = GetHistory[roles: roles, type: :reading]

    individualized_tasking_plans.map do |tasking_plan|
      build_reading_task(pages: @pages, history: histories[tasking_plan.target],
                         individualized_tasking_plan: tasking_plan, skip_dynamic: skip_dynamic)
    end
  end

  protected

  def k_ago_map
    ## Entries in the list have the form:
    ##   [from-this-many-events-ago, choose-this-many-exercises]
    [ [2,1], [4,1] ]
  end

  def num_personalized_exercises
    1
  end

  def build_reading_task(pages:, history:, individualized_tasking_plan:, skip_dynamic:)
    task = build_task(type: :reading, default_title: 'Reading',
                      individualized_tasking_plan: individualized_tasking_plan)

    reset_used_exercises

    add_core_steps!(task: task, pages: pages)

    unless skip_dynamic
      add_spaced_practice_exercise_steps!(
        task: task, core_page_ids: @pages.map(&:id),
        history: history, k_ago_map: k_ago_map, pool_type: :reading_dynamic
      )
      add_personalized_exercise_steps!(
        task: task, num_personalized_exercises: num_personalized_exercises,
        personalized_placeholder_strategy_class: Tasks::PlaceholderStrategies::IReadingPersonalized
      )
    end

    task
  end

  def add_core_steps!(task:, pages:)
    pages.each do |page|
      # Chapter intro pages get their titles from the chapter instead
      page_title = page.is_intro? ? page.chapter.title : page.title
      related_content = page.related_content(title: page_title)
      task_fragments(task: task, fragments: page.fragments, page_title: page_title,
                     page: page, related_content: related_content)
    end

    task
  end

end
