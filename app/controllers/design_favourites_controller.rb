class DesignFavouritesController < ApplicationController
  before_action :set_design

  def create
    @favourite = current_shop.design_favourites.new(design: @design, user: current_user)
    authorize @favourite
    @favourite.save!
    respond_to do |format|
      format.turbo_stream { render_favourite_button }
      format.html { redirect_back fallback_location: @design, notice: t("design_favourites.created") }
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_back fallback_location: @design
  end

  def destroy
    favourite = current_shop.design_favourites.find_by!(design: @design, user: current_user)
    authorize favourite
    favourite.destroy!
    @favourite = nil
    respond_to do |format|
      format.turbo_stream { render_favourite_button }
      format.html { redirect_back fallback_location: @design, notice: t("design_favourites.destroyed") }
    end
  end

  private

  def set_design
    @design = policy_scope(Design).find(params[:design_id])
  end

  def render_favourite_button
    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@design, :favourite),
      partial: "design_favourites/button",
      locals: { design: @design, favourite: @favourite, compact: params[:compact] == "1" }
    )
  end
end
