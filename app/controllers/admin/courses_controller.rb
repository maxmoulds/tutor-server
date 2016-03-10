class Admin::CoursesController < Admin::BaseController
  include Manager::CourseDetails
  include Lev::HandleWith

  before_action :get_schools, only: [:new, :edit]
  before_action :get_catalog_offerings, only: [:new, :edit]

  def index
    @query = params[:query]
    courses = SearchCourses[query: @query]
    @course_infos = CollectCourseInfo[courses: courses,
                                      with: [:teacher_names, :periods, :ecosystem_book]]
    @ecosystems = Content::ListEcosystems[]
    @incomplete_jobs = Jobba.where(state: :incomplete).to_a.select do |job|
      job.data.try :[], 'course_ecosystem'
    end
    @failed_jobs = Jobba.where(state: :failed).to_a.select do |job|
      job.data.try :[], 'course_ecosystem'
    end
    @job_path_proc = ->(job) { admin_job_path(job.id) }
  end

  def new
    @profile = CourseProfile::Models::Profile.new
  end

  def create
    handle_with(Admin::CoursesCreate,
                complete: -> (*) {
                  flash[:notice] = 'The course has been created.'
                  redirect_to admin_courses_path
                })
  end

  def edit
    get_course_details
  end

  def update
    handle_with(Admin::CoursesUpdate,
                params: course_params,
                complete: -> (*) {
                  flash[:notice] = 'The course has been updated.'
                  redirect_to admin_courses_path
                })
  end

  def destroy
    handle_with(Admin::CoursesDestroy,
                complete: -> (*) {
                  flash[:notice] = 'The course has been deleted.'
                  redirect_to admin_courses_path
                })
  end

  def bulk_update
    case params[:commit]
    when 'Set Ecosystem'
      bulk_set_ecosystem
    end
  end

  def bulk_set_ecosystem
    if params[:ecosystem_id].blank?
      flash[:error] = 'Please select an ecosystem'
    elsif params[:course_id].blank?
      flash[:error] = 'Please select the courses'
    else
      course_ids = params[:course_id]
      ecosystem = ::Content::Ecosystem.find(params[:ecosystem_id])
      courses = Entity::Course
        .where { id.in course_ids }
        .includes(:ecosystems)
        .select { |course|
          course.ecosystems.first.try(:id) != ecosystem.id
        }
      courses.each do |course|
        job_id = CourseContent::AddEcosystemToCourse.perform_later(
          course: Marshal.dump(course.reload),
          ecosystem: Marshal.dump(ecosystem)
        )
        job = Jobba.find(job_id)
        job.save(course_ecosystem: ecosystem.title, course_id: course.id)
      end
      flash[:notice] = 'Course ecosystem update background jobs queued.'
    end

    redirect_to admin_courses_path
  end

  def students
    handle_with(Admin::CoursesStudents, success: -> {
      flash[:notice] = 'Student roster has been uploaded.'
    },
    failure: -> {
      flash[:error] = ['Error uploading student roster'] +
                        @handler_result.errors.collect(&:message).flatten

    })

    redirect_to edit_admin_course_path(params[:id], anchor: 'roster')
  end

  def set_ecosystem
    if params[:ecosystem_id].blank?
      flash[:error] = 'Please select a course ecosystem'
    else
      course = Entity::Course.find(params[:id])
      ecosystem = ::Content::Ecosystem.find(params[:ecosystem_id])

      if GetCourseEcosystem[course: course] == ecosystem
        flash[:notice] = "Course ecosystem \"#{ecosystem.title}\" is already selected for \"#{course.profile.name}\""
      else
        CourseContent::AddEcosystemToCourse.perform_later(
          course: Marshal.dump(course.reload),
          ecosystem: Marshal.dump(ecosystem)
        )
        flash[:notice] = "Course ecosystem update to \"#{ecosystem.title}\" queued for \"#{course.profile.name}\""
      end
    end

    redirect_to edit_admin_course_path(params[:id], anchor: 'content')
  end

  private

  def course_params
    { id: params[:id], course: params.require(:course)
                                     .permit(:name,
                                             :appearance_code,
                                             :school_district_school_id,
                                             :catalog_offering_id,
                                             :is_concept_coach,
                                             teacher_ids: []) }
  end

  def get_schools
    @schools = SchoolDistrict::ListSchools[]
  end

  def get_catalog_offerings
    @catalog_offerings = Catalog::ListOfferings[]
  end
end
