class Api::V1::TaskStepsController < Api::V1::ApiController

  before_filter :get_task_step_and_tasked
  before_filter :error_if_student_and_needs_to_pay
  before_filter :populate_placeholders_if_needed, only: :show

  resource_description do
    api_versions "v1"
    short_description 'Represents a step in a task'
    description <<-EOS
      TBD
    EOS
  end

  ###############################################################
  # show
  ###############################################################

  api :GET, '/steps/:step_id', 'Gets the specified TaskStep'
  def show
    standard_read(@tasked, Api::V1::TaskedRepresenterMapper.representer_for(@tasked), true)
  end

  ###############################################################
  # update
  ###############################################################

  api :PUT, '/steps/:step_id', 'Updates the specified TaskStep'
  def update
    standard_update(@tasked, Api::V1::TaskedRepresenterMapper.representer_for(@tasked))
  end

  ###############################################################
  # completed
  ###############################################################

  api :PUT, '/steps/:step_id/completed',
            'Marks the specified TaskStep as completed (if applicable)'
  description <<-EOS
    Marks a task step as complete, which may create or modify other steps.
    The entire task is returned so the FE can update as needed.

    #{json_schema(Api::V1::TaskRepresenter, include: :readable)}
  EOS
  def completed
    OSU::AccessPolicy.require_action_allowed!(:mark_completed, current_api_user, @tasked)

    result = MarkTaskStepCompleted.call(task_step: @task_step)
    render_api_errors(result.errors) || respond_with(
      @task_step.task,
      responder: ResponderWithPutPatchDeleteContent,
      represent_with: Api::V1::TaskRepresenter
    )
  end

  ###############################################################
  # recovery
  ###############################################################

  api :PUT, '/steps/:step_id/recovery',
            'Requests a new exercise related to the given step'
  def recovery
    OSU::AccessPolicy.require_action_allowed!(:related_exercise, current_api_user, @tasked)

    result = Tasks::AddRelatedExerciseAfterStep.call(task_step: @task_step)

    render_api_errors(result.errors) || respond_with(
      result.outputs.related_exercise_step,
      responder: ResponderWithPutPatchDeleteContent,
      represent_with: Api::V1::TaskStepRepresenter
    )
  end

  protected

  def get_task_step_and_tasked
    Tasks::Models::TaskStep.transaction do
      @task_step = Tasks::Models::TaskStep.with_deleted.lock.find_by(id: params[:id])

      return render_api_errors(:no_exercises, :not_found) if @task_step.nil?

      @tasked = @task_step.tasked
    end
  end

  def populate_placeholders_if_needed
    return unless @tasked.is_a? Tasks::Models::TaskedPlaceholder

    Tasks::PopulatePlaceholderSteps[task: @task_step.task]

    @tasked.reload
  end

end
