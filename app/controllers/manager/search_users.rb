module Manager::SearchUsers
  def index
    params[:per_page] ||= 30
    @user_search = User::SearchUsers.call(
      params.slice(:query, :order_by, :page, :per_page).symbolize_keys
    ).outputs

    respond_to do |format|
      format.html
      format.json { render json: Api::V1::Admin::UserSearchRepresenter.new(@user_search).to_json }
    end
  end
end
