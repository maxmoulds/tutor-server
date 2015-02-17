module Api::V1
  class TaskedExerciseRepresenter < Roar::Decorator

    include TaskStepProperties

    property :correct_answer_id,
             type: Integer,
             if: -> (*) { task_step.completed? }

    property :answer_id,
             type: Integer,
             writeable: true,
             readable: true

    property :free_response,
             type: String,
             writeable: true,
             readable: true

    property :feedback_html,
             type: String,
             writeable: false,
             readable: true,
             if: -> (*) { task_step.completed? }

    property :content,
             type: String,
             writeable: false,
             readable: true,
             getter: -> (*) { task_step.content },
             schema_info: {
               required: false,
               description: "The exercise content as JSON"
             }
  end
end