require 'rails_helper'
require 'vcr_helper'

RSpec.describe Api::V1::TaskPlanWithStatsRepresenter, :type => :representer, :vcr => VCR_OPTS do

  let!(:number_of_students){ 2 }

  let!(:task_plan) {
    FactoryGirl.create :tasked_task_plan, number_of_students: number_of_students
  }

  let!(:representation) { Api::V1::TaskPlanWithStatsRepresenter.new(task_plan).as_json }

  it "represents a tasked exercise's stats" do
    expect(representation).to include(
      "id" => task_plan.id,
      "type" => "reading",
      "stats" => {
        "course" => a_hash_including(
          "total_count"              => 2,
          "complete_count"           => 0,
          "partially_complete_count" => 0,
          "current_pages"            => a_collection_containing_exactly(
            a_hash_including(
              "id"     => task_plan.settings['page_ids'].first,
              "number" => 1,
              "title"  => "Force",
              "student_count"   => 2,
              "correct_count"   => 0,
              "incorrect_count" => 0
            )
          ),
          "spaced_pages" => a_collection_containing_exactly(
            a_hash_including(
              "id"     => 0,
              "number" => 0,
              "title"  => "",
              "student_count"   => 0,
              "correct_count"   => 0,
              "incorrect_count" => 0
            )
          )
        ),
        "periods" => []
      }
    )
  end

end