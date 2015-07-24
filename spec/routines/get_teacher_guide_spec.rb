require 'rails_helper'
require 'vcr_helper'
require 'database_cleaner'

RSpec.describe GetTeacherGuide do

  before(:all) do
    DatabaseCleaner.start
    @course = Entity::Course.create!

    @period = CreatePeriod[course: @course]
    @second_period = CreatePeriod[course: @course]

    @teacher = Entity::User.create!
    @student = Entity::User.create!
    @second_student = Entity::User.create!

    @role = AddUserAsPeriodStudent[period: @period, user: @student]
    @second_role = AddUserAsPeriodStudent[period: @second_period, user: @second_student]
    @teacher_role = AddUserAsCourseTeacher[course: @course, user: @teacher]

    VCR.use_cassette("GetCourseGuide/setup_course_guide", VCR_OPTS) do
      capture_stdout do
        CreateStudentHistory[course: @course, roles: [@role, @second_role]]
      end
    end
  end

  after(:all) do
    DatabaseCleaner.clean
  end

  it 'returns all course guide periods for teachers' do
    result = described_class[role: @teacher_role]

    expect(result).to include({
      period_id: @period.id,
      title: 'Physics',
      page_ids: [kind_of(Integer)]*4,
      children: array_including(kind_of(Hash))
    },
    {
      period_id: @second_period.id,
      title: 'Physics',
      page_ids: [kind_of(Integer)]*4,
      children: array_including(kind_of(Hash))
    })
  end

  it 'includes the chapter stats for the periods' do
    period_1_chapter_1 = described_class[role: @teacher_role].first['children'].first

    expect([period_1_chapter_1]).to match a_hash_including(
      "title"=>"Acceleration",
      "chapter_section"=>[3],
      "questions_answered_count"=>2,
      "current_level"=>kind_of(Float),
      "interpretation"=>kind_of(String),
      "practice_count"=>0,
      "page_ids"=>[kind_of(Integer)],
      "children" => array_including(kind_of(Hash))
    )

    period_2_chapter_1 = described_class[role: @teacher_role].second['children'].first

    expect([period_2_chapter_1]).to match a_hash_including(
      "title"=>"Acceleration",
      "chapter_section"=>[3],
      "questions_answered_count"=>3,
      "current_level"=>kind_of(Float),
      "interpretation"=>kind_of(String),
      "practice_count"=>0,
      "page_ids"=>[kind_of(Integer)],
      "children" => array_including(kind_of(Hash))
    )
  end

  it 'includes the page stats for the periods' do
    period_1_pages = described_class[role: @teacher_role].first['children'].first['children']

    expect(period_1_pages).to include(
      a_hash_including("title"=>"Acceleration",
                       "chapter_section"=>[3, 1],
                       "questions_answered_count"=>2,
                       "current_level"=>kind_of(Float),
                       "interpretation"=>kind_of(String),
                       "practice_count"=>0,
                       "page_ids"=>[kind_of(Integer)])
    )

    period_2_pages = described_class[role: @teacher_role].second['children'].first['children']

    expect(period_2_pages).to include(
      a_hash_including("title"=>"Representing Acceleration with Equations and Graphs",
                       "chapter_section"=>[3, 2],
                       "questions_answered_count"=>3,
                       "current_level"=>kind_of(Float),
                       "interpretation"=>kind_of(String),
                       "practice_count"=>0,
                       "page_ids"=>[kind_of(Integer)])
    )
  end

end
