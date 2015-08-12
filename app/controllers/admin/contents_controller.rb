class Admin::ContentsController < Admin::BaseController
  def index
    @ecosystems = Content::ListEcosystems[]
  end

  def import
    @default_archive_url = OpenStax::Cnx::V1.archive_url_base
    import_book if request.post?
  end

  protected

  def import_book
    archive_url = params[:archive_url].present? ? params[:archive_url] : @default_archive_url

    # Check whether book exists
    book = get_book(archive_url, params[:cnx_id])
    unless book.nil?
      flash[:error] = "Book \"#{book.title}\" already imported."
      return render :import
    end

    OpenStax::Cnx::V1.with_archive_url(url: archive_url) do
      ecosystem = FetchAndImportBookAndCreateEcosystem.call(id: params[:cnx_id]).outputs.ecosystem
      flash[:notice] = "Book \"#{ecosystem.books.first.title}\" imported."
    end
    redirect_to admin_contents_path
  end

  def get_book(archive_url, cnx_id)
    OpenStax::Cnx::V1.with_archive_url(url: archive_url) do
      url = OpenStax::Cnx::V1.url_for(cnx_id)
      Content::Models::Book.where(url: url).first
    end
  end
end