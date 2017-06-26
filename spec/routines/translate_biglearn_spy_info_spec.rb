require 'rails_helper'

RSpec.describe TranslateBiglearnSpyInfo, type: :routine do

  before(:all) do
    @current_task = FactoryGirl.create :tasks_task
    @spaced_task = FactoryGirl.create :tasks_task
  end

  let(:given_exercise_uuid_1) { SecureRandom.uuid }
  let(:given_exercise_uuid_2) { SecureRandom.uuid }
  let(:given_exercise_uuid_3) { SecureRandom.uuid }

  let(:given_book_container_uuid_1) { SecureRandom.uuid }
  let(:given_book_container_uuid_2) { SecureRandom.uuid }
  let(:given_book_container_uuid_3) { SecureRandom.uuid }
  let(:given_book_container_uuid_4) { SecureRandom.uuid }

  let(:spy_info) do
    {
      assignment_history: {
        0 => {
          assignment_uuid: @current_task.uuid,
          book_container_uuids: [ given_book_container_uuid_1, given_book_container_uuid_2 ]
        },
        1 => {
          assignment_uuid: @spaced_task.uuid,
          book_container_uuids: [ given_book_container_uuid_3, given_book_container_uuid_4 ]
        }
      },
      exercises: {
        given_exercise_uuid_1.to_sym => { k_ago: 1, is_random_ago: false },
        given_exercise_uuid_2.to_sym => { k_ago: 3, is_random_ago: false },
        given_exercise_uuid_3.to_sym => { k_ago: 2, is_random_ago: true }
      }
    }
  end

  let(:expected_translated_spy_info) do
    {
      task_history: {
        0 => {
          task_id: @current_task.id,
          task_uuid: @current_task.uuid,
          book_container_uuids: [ given_book_container_uuid_1, given_book_container_uuid_2 ]
        },
        1 => {
          task_id: @spaced_task.id,
          task_uuid: @spaced_task.uuid,
          book_container_uuids: [ given_book_container_uuid_3, given_book_container_uuid_4 ]
        }
      },
      exercises: {
        given_exercise_uuid_1 => { k_ago: 1, is_random_ago: false },
        given_exercise_uuid_2 => { k_ago: 3, is_random_ago: false },
        given_exercise_uuid_3 => { k_ago: 2, is_random_ago: true }
      }
    }.deep_stringify_keys
  end

  let(:translated_spy_info) { described_class.call(spy_info: spy_info).outputs.spy_info }

  it 'translates spy info coming from Biglearn' do
    expect(translated_spy_info).to eq expected_translated_spy_info
  end

end