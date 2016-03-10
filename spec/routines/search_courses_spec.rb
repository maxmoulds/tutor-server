require 'rails_helper'

RSpec.describe SearchCourses, type: :routine do

  let!(:tutor_school) { FactoryGirl.create(:school, name: 'TTS') }
  let!(:cc_school)    { FactoryGirl.create(:school, name: 'CCS') }

  let!(:offering) {
    FactoryGirl.create(:catalog_offering,
                       salesforce_book_name: 'College Physics (Algebra)',
                       description: 'Introductory two-semester physics book')
  }

  let!(:course_1) { FactoryGirl.create(
    :course_profile_profile, name: 'Physics', school: tutor_school, offering: offering
  ).course }
  let!(:course_2) { FactoryGirl.create(
    :course_profile_profile, name: 'Biology', school: tutor_school
  ).course }
  let!(:course_3) { FactoryGirl.create(
    :course_profile_profile, name: 'Concept Coach', school: cc_school
  ).course }

  let!(:teacher_user) { FactoryGirl.create(:user, first_name: 'Charles') }

  before do
    AddUserAsCourseTeacher[course: course_1, user: teacher_user]
    AddUserAsCourseTeacher[course: course_3, user: teacher_user]
  end

  it 'returns all courses in alphabetical order if the query is nil' do
    courses = described_class[query: nil].to_a
    expect(courses).to eq [course_2, course_3, course_1]
  end

  it 'returns all courses in alphabetical order if the query is blank' do
    courses = described_class[query: ''].to_a
    expect(courses).to eq [course_2, course_3, course_1]
  end

  it 'returns courses whose name matches the given query, in alphabetical order' do
    courses = described_class[query: 'i'].to_a
    expect(courses).to eq [course_2, course_1]

    courses = described_class[query: 'o'].to_a
    expect(courses).to eq [course_2, course_3, course_1]

    courses = described_class[query: 'o,i'].to_a
    expect(courses).to eq [course_2, course_3, course_1]

    courses = described_class[query: 'bIo'].to_a
    expect(courses).to eq [course_2]

    courses = described_class[query: 'physics'].to_a
    expect(courses).to eq [course_1]

    courses = described_class[query: 'name:i'].to_a
    expect(courses).to eq [course_2, course_1]

    courses = described_class[query: 'name:o'].to_a
    expect(courses).to eq [course_2, course_3]

    courses = described_class[query: 'name:o,i'].to_a
    expect(courses).to eq [course_2, course_3, course_1]

    courses = described_class[query: 'name:bIo'].to_a
    expect(courses).to eq [course_2]

    courses = described_class[query: 'name:physics'].to_a
    expect(courses).to eq [course_1]
  end

  it 'returns courses whose school\'s name matches the given query, in alphabetical order' do
    courses = described_class[query: 'ts'].to_a
    expect(courses).to eq [course_2, course_1]

    courses = described_class[query: 'ccs'].to_a
    expect(courses).to eq [course_3]

    courses = described_class[query: 'school:ts'].to_a
    expect(courses).to eq [course_2, course_1]

    courses = described_class[query: 'school:ccs'].to_a
    expect(courses).to eq [course_3]
  end

  it 'returns courses whose teacher\'s name matches the given query, in alphabetical order' do
    courses = described_class[query: 'cHaRlEs'].to_a
    expect(courses).to eq [course_3, course_1]

    courses = described_class[query: 'rLe'].to_a
    expect(courses).to eq [course_3, course_1]

    courses = described_class[query: 'teacher:cHaRlEs'].to_a
    expect(courses).to eq [course_3, course_1]

    courses = described_class[query: 'teacher:rLe'].to_a
    expect(courses).to eq [course_3, course_1]
  end

  it 'returns courses whose book name matches the given query' do
    courses = described_class[query: 'algebra'].to_a
    expect(courses).to eq [course_1]

    courses = described_class[query: 'offering:algebra'].to_a
    expect(courses).to eq [course_1]
  end

  it 'returns courses whose book description matches the given query' do
    courses = described_class[query: 'introductory'].to_a
    expect(courses).to eq [course_1]

    courses = described_class[query: 'offering:introductory'].to_a
    expect(courses).to eq [course_1]
  end
end
