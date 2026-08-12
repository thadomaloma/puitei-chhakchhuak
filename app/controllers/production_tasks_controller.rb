class ProductionTasksController < ApplicationController
  before_action :set_task

  def claim
    authorize @task, :claim?
    @task.claim!(current_user)
    redirect_back fallback_location: production_path, notice: t("production.claimed")
  end

  def assign
    authorize @task, :assign?
    assignee = policy_scope(User).find(params.require(:production_task).fetch(:assigned_to_id))
    @task.assign!(current_user, assignee)
    redirect_back fallback_location: production_path, notice: t("production.assigned", name: assignee.name)
  end

  def start
    authorize @task, :start?
    @task.start!(current_user)
    redirect_back fallback_location: production_path, notice: t("production.started")
  end

  def complete
    authorize @task, :complete?
    @task.complete!(current_user, notes: transition_notes)
    redirect_back fallback_location: production_path, notice: t("production.completed")
  end

  def skip
    authorize @task, :skip?
    @task.skip!(current_user, notes: transition_notes)
    redirect_back fallback_location: production_path, notice: t("production.skipped")
  end

  def reopen
    authorize @task, :reopen?
    @task.reopen!(current_user, notes: transition_notes)
    redirect_back fallback_location: production_path, notice: t("production.reopened")
  end

  private

  def set_task
    @task = policy_scope(ProductionTask).includes(order_item: { order: :branch }).find(params[:id])
  end

  def transition_notes
    params.dig(:production_task, :notes)
  end

  rescue_from ProductionTask::InvalidTransition do |error|
    redirect_back fallback_location: production_path, alert: error.message
  end
end
