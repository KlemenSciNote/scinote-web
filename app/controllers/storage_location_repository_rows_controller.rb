# frozen_string_literal: true

class StorageLocationRepositoryRowsController < ApplicationController
  before_action :check_storage_locations_enabled, except: :destroy
  before_action :load_storage_location_repository_row, only: %i(update destroy move)
  before_action :load_storage_location
  before_action :load_repository_row, only: %i(create update destroy move)
  before_action :check_read_permissions, except: %i(create actions_toolbar)
  before_action :check_manage_permissions, only: %i(create update destroy)

  def index
    storage_location_repository_row = Lists::StorageLocationRepositoryRowsService.new(
      current_team, params
    ).call
    render json: storage_location_repository_row,
           each_serializer: Lists::StorageLocationRepositoryRowSerializer,
           meta: (pagination_dict(storage_location_repository_row) unless @storage_location.with_grid?)
  end

  def create
    ActiveRecord::Base.transaction do
      @storage_location_repository_row = StorageLocationRepositoryRow.new(
        repository_row: @repository_row,
        storage_location: @storage_location,
        metadata: storage_location_repository_row_params[:metadata] || {},
        created_by: current_user
      )

      if @storage_location_repository_row.save
        log_activity(:storage_location_repository_row_created)
        render json: @storage_location_repository_row,
               serializer: Lists::StorageLocationRepositoryRowSerializer
      else
        render json: @storage_location_repository_row.errors, status: :unprocessable_entity
      end
    end
  end

  def update
    ActiveRecord::Base.transaction do
      @storage_location_repository_row.update(storage_location_repository_row_params)

      if @storage_location_repository_row.save
        log_activity(:storage_location_repository_row_moved)
        render json: @storage_location_repository_row,
               serializer: Lists::StorageLocationRepositoryRowSerializer
      else
        render json: @storage_location_repository_row.errors, status: :unprocessable_entity
      end
    end
  end

  def move
    ActiveRecord::Base.transaction do
      @storage_location_repository_row.discard
      @storage_location_repository_row = StorageLocationRepositoryRow.create!(
        repository_row: @repository_row,
        storage_location: @storage_location,
        metadata: storage_location_repository_row_params[:metadata] || {},
        created_by: current_user
      )
      log_activity(:storage_location_repository_row_moved)
      render json: @storage_location_repository_row,
             serializer: Lists::StorageLocationRepositoryRowSerializer
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      raise ActiveRecord::Rollback
    end
  end

  def destroy
    ActiveRecord::Base.transaction do
      if @storage_location_repository_row.discard
        log_activity(:storage_location_repository_row_deleted)
        render json: {}
      else
        render json: { errors: @storage_location_repository_row.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  def actions_toolbar
    render json: {
      actions: Toolbars::StorageLocationRepositoryRowsService.new(
        current_user,
        items_ids: JSON.parse(params[:items]).pluck('id')
      ).actions
    }
  end

  private

  def check_storage_locations_enabled
    render_403 unless StorageLocation.storage_locations_enabled?
  end

  def load_storage_location_repository_row
    @storage_location_repository_row = StorageLocationRepositoryRow.find(
      storage_location_repository_row_params[:id]
    )
    render_404 unless @storage_location_repository_row
  end

  def load_storage_location
    @storage_location = StorageLocation.viewable_by_user(current_user).find(
      storage_location_repository_row_params[:storage_location_id]
    )
    render_404 unless @storage_location
  end

  def load_repository_row
    @repository_row = RepositoryRow.find(storage_location_repository_row_params[:repository_row_id])
    render_404 unless @repository_row
  end

  def storage_location_repository_row_params
    params.permit(:id, :storage_location_id, :repository_row_id,
                  metadata: { position: [] })
  end

  def check_read_permissions
    render_403 unless can_read_storage_location?(@storage_location)
  end

  def check_manage_permissions
    render_403 unless can_manage_storage_location?(@storage_location)
  end

  def log_activity(type_of, message_items = {})
    Activities::CreateActivityService
      .call(activity_type: type_of,
            owner: current_user,
            team: @storage_location.team,
            subject: @storage_location_repository_row.repository_row,
            message_items: {
              storage_location: @storage_location_repository_row.storage_location_id,
              repository_row: @storage_location_repository_row.repository_row_id,
              position: @storage_location_repository_row.human_readable_position,
              user: current_user.id
            }.merge(message_items))
  end
end